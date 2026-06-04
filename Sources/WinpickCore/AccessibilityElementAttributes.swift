import ApplicationServices
import CoreGraphics
import Foundation

enum AccessibilityElementAttributes {
    static func windows(of element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXWindowsAttribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value as? [AXUIElement]
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let axElement = value,
              CFGetTypeID(axElement) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return (axElement as! AXUIElement)
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return ""
        }
        return value as? String ?? ""
    }

    static func frame(of element: AXUIElement) -> WindowFrame? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionAX = positionValue,
              let sizeAX = sizeValue
        else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAX as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeAX as! AXValue, .cgSize, &size)
        else {
            return nil
        }

        return WindowFrame(
            x: point.x,
            y: point.y,
            width: size.width,
            height: size.height
        )
    }
}
