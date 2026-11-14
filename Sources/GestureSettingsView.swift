// SPDX-License-Identifier: MIT
import AppKit

private func gestureText(_ text:String,size:CGFloat=13,weight:NSFont.Weight = .regular,color:NSColor = .labelColor)->NSTextField {
    let field=NSTextField(labelWithString:text);field.font = .systemFont(ofSize:size,weight:weight);field.textColor=color
    field.lineBreakMode = .byTruncatingTail;return field
}
private func centerGestureControl(_ control:NSView,at y:CGFloat) {
    control.frame.origin.y += y-control.alignmentRect(forFrame:control.frame).midY
}
private func drawGesture(_ points:[Point],in rect:NSRect,color:NSColor,width:CGFloat) {
    let points=points.filter{$0.x.isFinite && $0.y.isFinite}
    guard points.count>1 else{return}
    let minX=points.map(\.x).min()!,maxX=points.map(\.x).max()!,minY=points.map(\.y).min()!,maxY=points.map(\.y).max()!
    let scale=min(rect.width/max(maxX-minX,0.001),rect.height/max(maxY-minY,0.001))
    let cx=(minX+maxX)/2,cy=(minY+maxY)/2
    let path=NSBezierPath();path.lineWidth=width;path.lineCapStyle = .round;path.lineJoinStyle = .round
    for (i,p) in points.enumerated() {
        let point=NSPoint(x:rect.midX+(p.x-cx)*scale,y:rect.midY+(p.y-cy)*scale)
        if i == 0 || points[i-1].stroke != p.stroke {path.move(to:point)}else{path.line(to:point)}
    }
    color.setStroke();path.stroke()
}

private final class GestureThumbnail:NSView {
    var points=[Point]()
    override func draw(_ dirtyRect:NSRect) {
        NSColor.quaternaryLabelColor.withAlphaComponent(0.1).setFill()
        NSBezierPath(roundedRect:bounds,xRadius:10,yRadius:10).fill()
        drawGesture(points,in:bounds.insetBy(dx:10,dy:10),color:.controlAccentColor,width:2)
    }
}
private final class RecordGestureButton:NSButton {
    var points=[Point]() {didSet{needsDisplay=true}}
    override var isFlipped:Bool{false}
    override func draw(_ dirtyRect:NSRect) {
        let tile=NSRect(x:8,y:24,width:80,height:80)
        let plate=NSBezierPath(roundedRect:tile.insetBy(dx:0.5,dy:0.5),xRadius:12,yRadius:12)
        (isHighlighted ? NSColor.controlAccentColor.withAlphaComponent(0.14):NSColor.quaternaryLabelColor.withAlphaComponent(0.1)).setFill();plate.fill()
        NSColor.separatorColor.setStroke();plate.lineWidth=0.5;plate.stroke()
        if points.isEmpty {
            NSColor.controlAccentColor.setStroke();let plus=NSBezierPath();plus.lineWidth=2;plus.lineCapStyle = .round
            plus.move(to:NSPoint(x:tile.midX-11,y:tile.midY));plus.line(to:NSPoint(x:tile.midX+11,y:tile.midY))
            plus.move(to:NSPoint(x:tile.midX,y:tile.midY-11));plus.line(to:NSPoint(x:tile.midX,y:tile.midY+11));plus.stroke()
        }else{
            drawGesture(points,in:tile.insetBy(dx:12,dy:12),color:.controlAccentColor,width:2.5)
        }
        let paragraph=NSMutableParagraphStyle();paragraph.alignment = .center
        let action=points.isEmpty ? "Record gesture":"Record again"
        (action as NSString).draw(in:NSRect(x:0,y:2,width:96,height:16),withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:NSColor.controlAccentColor,.paragraphStyle:paragraph])
    }
}
final class GestureActionButton:NSButton {
    let gestureID:UUID
    init(title:String,id:UUID,target:AnyObject?,action:Selector) {
        gestureID=id;super.init(frame:.zero);self.title=title;self.target=target;self.action=action;bezelStyle = .rounded
    }
    required init?(coder:NSCoder){fatalError()}
}
private final class GestureRow:NSView {
    static let height:CGFloat=66
    init(gesture:Gesture,width:CGFloat,target:AnyObject?,edit:Selector,delete:Selector) {
        super.init(frame:NSRect(x:0,y:0,width:width,height:Self.height))
        let preview=GestureThumbnail(frame:NSRect(x:16,y:9,width:48,height:48));preview.points=gesture.samples.first ?? []
        preview.setAccessibilityElement(true);preview.setAccessibilityLabel("Drawing for "+gesture.displayTitle);addSubview(preview)
        let title=gestureText(gesture.displayTitle,weight:.semibold);title.frame=NSRect(x:80,y:35,width:width-256,height:18);title.toolTip=gesture.displayTitle;addSubview(title)
        let detail=gestureText("Open app – "+gesture.appName,size:11,color:.secondaryLabelColor)
        detail.frame=NSRect(x:80,y:17,width:width-256,height:16);detail.toolTip=gesture.app;addSubview(detail)
        let editButton=GestureActionButton(title:"Edit",id:gesture.id,target:target,action:edit)
        editButton.frame=NSRect(x:width-156,y:15,width:60,height:28);centerGestureControl(editButton,at:Self.height/2)
        editButton.setAccessibilityLabel("Edit "+gesture.displayTitle+", opens "+gesture.appName);addSubview(editButton)
        let deleteButton=GestureActionButton(title:"Delete",id:gesture.id,target:target,action:delete)
        deleteButton.frame=NSRect(x:width-84,y:15,width:68,height:28);centerGestureControl(deleteButton,at:Self.height/2)
        deleteButton.setAccessibilityLabel("Delete "+gesture.displayTitle+", opens "+gesture.appName);addSubview(deleteButton)
        let divider=NSBox(frame:NSRect(x:16,y:0,width:width-32,height:1));divider.boxType = .separator;addSubview(divider)
    }
    required init?(coder:NSCoder){fatalError()}
}
private final class GestureListDocument:NSView {override var isFlipped:Bool{true}}

final class GestureSettingsView:NSView,NSTextFieldDelegate {
    var onTitle:((String)->Void)?
    var onRecord:(()->Void)?
    var onChooseApp:(()->Void)?
    var onSave:(()->Void)?
    var onCancel:(()->Void)?
    var onEdit:((UUID)->Void)?
    var onDelete:((UUID)->Void)?
    private let heading=gestureText("Create new gesture",size:15,weight:.semibold)
    private let titleInput=NSTextField()
    private let type=NSPopUpButton()
    private let application=NSButton()
    private let record=RecordGestureButton()
    private let saveButton=NSButton(title:"Save",target:nil,action:nil)
    private let cancelButton=NSButton(title:"Cancel",target:nil,action:nil)
    private let feedback=gestureText("",size:11,color:.labelColor.withAlphaComponent(0.76))
    private let scroll=NSScrollView()
    private let listHeader=gestureText("",size:15,weight:.semibold)
    override init(frame:NSRect) {
        super.init(frame:frame)
        heading.frame=NSRect(x:28,y:396,width:584,height:22);addSubview(heading)
        let editor=NSBox(frame:NSRect(x:24,y:256,width:592,height:128))
        editor.boxType = .custom;editor.borderColor = .separatorColor;editor.borderWidth=0.5;editor.cornerRadius=12
        editor.fillColor = .controlBackgroundColor;editor.contentViewMargins = .zero;addSubview(editor)
        let content=editor.contentView!
        record.frame=NSRect(x:0,y:12,width:96,height:104);record.title="";record.isBordered=false;record.target=self;record.action = #selector(recordPressed)
        record.setAccessibilityLabel("Record gesture");record.toolTip="Record three examples. Click again to re-record."
        content.addSubview(record)
        let titleLabel=gestureText("Title");let typeLabel=gestureText("Type");let appLabel=gestureText("App")
        for (field,y) in [(titleLabel,CGFloat(94)),(typeLabel,58),(appLabel,58)] {
            field.frame=NSRect(x:120,y:y,width:40,height:18);content.addSubview(field)
        }
        appLabel.frame.origin.x=344;appLabel.frame.size.width=32
        titleInput.frame=NSRect(x:168,y:90,width:408,height:26);titleInput.placeholderString="Optional";titleInput.delegate=self
        titleInput.setAccessibilityLabel("Gesture title (optional)");content.addSubview(titleInput)
        type.frame=NSRect(x:168,y:54,width:152,height:28);type.addItem(withTitle:"Open app")
        type.setAccessibilityLabel("Gesture action type");content.addSubview(type)
        application.frame=NSRect(x:384,y:54,width:192,height:28);application.bezelStyle = .rounded
        application.alignment = .left;application.imagePosition = .imageLeading;application.font = .systemFont(ofSize:13)
        application.target=self;application.action = #selector(choosePressed);application.setAccessibilityLabel("Application");content.addSubview(application)
        saveButton.frame=NSRect(x:480,y:6,width:96,height:30);saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent="\r";saveButton.target=self;saveButton.action = #selector(savePressed);content.addSubview(saveButton)
        cancelButton.frame=NSRect(x:372,y:6,width:96,height:30);cancelButton.bezelStyle = .rounded
        cancelButton.target=self;cancelButton.action = #selector(cancelPressed);content.addSubview(cancelButton)
        for (label,control) in [(titleLabel,titleInput as NSView),(typeLabel,type as NSView),(appLabel,application as NSView)] {
            label.frame.size.height=ceil(label.intrinsicContentSize.height)
            label.frame.origin.y=control.alignmentRect(forFrame:control.frame).midY-label.frame.height/2
        }
        centerGestureControl(saveButton,at:22)
        centerGestureControl(cancelButton,at:22)
        feedback.frame=NSRect(x:120,y:5,width:240,height:30);feedback.maximumNumberOfLines=2;feedback.lineBreakMode = .byWordWrapping
        feedback.isHidden=true;content.addSubview(feedback)
        listHeader.frame=NSRect(x:28,y:214,width:584,height:22);addSubview(listHeader)
        scroll.frame=NSRect(x:24,y:8,width:592,height:198);scroll.autohidesScrollers=false
        scroll.scrollerStyle = .legacy;scroll.drawsBackground=false;scroll.borderType = .noBorder
        scroll.wantsLayer=true;scroll.layer?.cornerRadius=12;scroll.layer?.masksToBounds=true
        addSubview(scroll)
    }
    required init?(coder:NSCoder){fatalError()}
    func render(gestures:[Gesture],draft:GestureDraft,focusTitle:Bool=false) {
        heading.stringValue=draft.editingID == nil ? "Create new gesture":"Edit gesture"
        titleInput.stringValue=draft.title
        record.points=draft.samples.first ?? []
        record.title=draft.samples.isEmpty ? "Record gesture":"Record again"
        record.setAccessibilityLabel((draft.samples.isEmpty ? "Record gesture":"Record again")+", \(min(draft.samples.count,3)) of 3 recorded")
        application.title=draft.appPath.isEmpty ? "Choose app…":URL(fileURLWithPath:draft.appPath).deletingPathExtension().lastPathComponent
        let icon=draft.appPath.isEmpty ? nil:NSWorkspace.shared.icon(forFile:draft.appPath).copy() as? NSImage
        icon?.size=NSSize(width:16,height:16);application.image=icon
        application.imagePosition=draft.appPath.isEmpty ? .noImage:.imageLeading
        application.toolTip=draft.appPath.isEmpty ? "Choose the application to open":draft.appPath
        updateSaveEnabled(draft.canSave)
        cancelButton.isEnabled = !draft.isEmpty
        setMessage("")
        let visible=draft.visibleGestures(in:gestures)
        let sectionTitle=NSMutableAttributedString(string:"Saved gestures",attributes:[.font:NSFont.systemFont(ofSize:15,weight:.semibold),.foregroundColor:NSColor.labelColor])
        sectionTitle.append(NSAttributedString(string:"  \(visible.count)",attributes:[.font:NSFont.systemFont(ofSize:15),.foregroundColor:NSColor.secondaryLabelColor]))
        listHeader.attributedStringValue=sectionTitle
        scroll.hasVerticalScroller = CGFloat(visible.count)*GestureRow.height > scroll.bounds.height
        scroll.tile()
        let document=GestureListDocument(frame:NSRect(x:0,y:0,width:scroll.contentSize.width,height:max(scroll.contentSize.height,CGFloat(visible.count)*GestureRow.height)))
        if visible.isEmpty {
            let empty=gestureText(draft.editingID == nil ? "No saved gestures yet":"This gesture is being edited above",color:.secondaryLabelColor)
            empty.frame=NSRect(x:16,y:24,width:560,height:20);document.addSubview(empty)
        }
        for (index,gesture) in visible.enumerated() {
            let row=GestureRow(gesture:gesture,width:document.frame.width,target:self,edit:#selector(editPressed(_:)),delete:#selector(deletePressed(_:)))
            row.frame.origin.y=CGFloat(index)*GestureRow.height;document.addSubview(row)
        }
        scroll.documentView=document;scroll.contentView.scroll(to:.zero);scroll.reflectScrolledClipView(scroll.contentView)
        if focusTitle {window?.makeFirstResponder(titleInput);titleInput.selectText(nil)}
    }
    func setMessage(_ text:String){feedback.stringValue=text;feedback.toolTip=text;feedback.isHidden=text.isEmpty}
    func updateSaveEnabled(_ enabled:Bool){
        saveButton.isEnabled=enabled;saveButton.bezelColor=enabled ? .controlAccentColor:nil
        saveButton.contentTintColor=enabled ? .white:nil
        saveButton.attributedTitle=NSAttributedString(string:"Save",attributes:[.font:saveButton.font ?? NSFont.systemFont(ofSize:13),.foregroundColor:enabled ? NSColor.white:NSColor.disabledControlTextColor])
        cancelButton.isEnabled=true
    }
    func controlTextDidChange(_ notification:Notification){onTitle?(titleInput.stringValue)}
    @objc private func recordPressed(){onRecord?()}
    @objc private func choosePressed(){onChooseApp?()}
    @objc private func savePressed(){onSave?()}
    @objc private func cancelPressed(){window?.makeFirstResponder(nil);onCancel?()}
    @objc private func editPressed(_ sender:GestureActionButton){window?.makeFirstResponder(nil);onEdit?(sender.gestureID)}
    @objc private func deletePressed(_ sender:GestureActionButton){onDelete?(sender.gestureID)}
}
