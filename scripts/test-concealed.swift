// Test helper: puts a fake password on the clipboard marked the way password managers do.
// ClipStack must NOT record it. Run: swift scripts/test-concealed.swift
import AppKit

let pasteboard = NSPasteboard.general
pasteboard.clearContents()
let item = NSPasteboardItem()
item.setString("pretend-secret-123", forType: .string)
item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
pasteboard.writeObjects([item])
print("Wrote a concealed test item; ClipStack must not record it.")
