package ai.xkiro.studio.device

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class StudioAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile var instance: StudioAccessibilityService? = null
    }

    override fun onServiceConnected() { instance = this }
    override fun onInterrupt() = Unit
    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit
    override fun onDestroy() { if (instance === this) instance = null; super.onDestroy() }

    fun snapshot(maxNodes: Int = 220): String {
        val root = rootInActiveWindow ?: return "(sem árvore de acessibilidade)"
        val lines = mutableListOf<String>()
        fun walk(node: AccessibilityNodeInfo?, depth: Int) {
            if (node == null || lines.size >= maxNodes) return
            val text = node.text?.toString()?.take(140).orEmpty()
            val desc = node.contentDescription?.toString()?.take(140).orEmpty()
            val id = node.viewIdResourceName.orEmpty()
            if (text.isNotBlank() || desc.isNotBlank() || id.isNotBlank() || node.isClickable || node.isEditable) {
                lines += "${"  ".repeat(depth.coerceAtMost(6))}${node.className} text=$text desc=$desc id=$id clickable=${node.isClickable} editable=${node.isEditable} focused=${node.isFocused}"
            }
            for (i in 0 until node.childCount) walk(node.getChild(i), depth + 1)
        }
        walk(root, 0)
        return lines.joinToString("\n")
    }

    fun clickText(target: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByText(target)
        val node = nodes.firstOrNull() ?: return false
        var cur: AccessibilityNodeInfo? = node
        while (cur != null) {
            if (cur.isClickable) return cur.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            cur = cur.parent
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
    }

    fun setFocusedText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        var target = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        if (target == null || !target.isEditable) {
            fun findEditable(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
                if (node == null) return null
                if (node.isEditable) return node
                for (i in 0 until node.childCount) {
                    val found = findEditable(node.getChild(i))
                    if (found != null) return found
                }
                return null
            }
            target = findEditable(root)
        }
        target ?: return false
        target.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
        }
        return target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    }

    fun scrollForward(): Boolean {
        val root = rootInActiveWindow ?: return false
        fun findScrollable(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
            if (node == null) return null
            if (node.isScrollable) return node
            for (i in 0 until node.childCount) {
                val found = findScrollable(node.getChild(i))
                if (found != null) return found
            }
            return null
        }
        return findScrollable(root)?.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD) ?: false
    }

    fun back(): Boolean = performGlobalAction(GLOBAL_ACTION_BACK)
    fun home(): Boolean = performGlobalAction(GLOBAL_ACTION_HOME)

    fun tap(x: Float, y: Float): Boolean {
        val p = Path().apply { moveTo(x, y) }
        val g = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(p, 0, 80))
            .build()
        return dispatchGesture(g, null, null)
    }
}
