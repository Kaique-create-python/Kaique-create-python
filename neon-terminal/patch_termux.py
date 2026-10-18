#!/usr/bin/env python3
"""Patch official termux-app with Neon Terminal v0.1 visuals and a live session monitor."""
from pathlib import Path
import sys

def replace(root, name, old, new):
    p = root / name
    s = p.read_text(encoding="utf-8")
    if s.count(old) != 1:
        raise RuntimeError(f"Upstream changed: expected one match in {name}: {old[:72]}")
    p.write_text(s.replace(old, new, 1), encoding="utf-8")
    print("PATCH", name)

root = Path(sys.argv[1]).resolve()
icon = Path(sys.argv[2]).resolve()
replace(root, "app/src/main/res/values/strings.xml",
        '<string name="application_name">&TERMUX_APP_NAME;</string>',
        '<string name="application_name">Neon Terminal</string>')
(root / "app/src/main/res/values/colors.xml").write_text("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="neon_bg">#080A10</color>
    <color name="neon_surface">#151019</color>
    <color name="neon_red">#FF315A</color>
    <color name="neon_red_dim">#602236</color>
</resources>
""", encoding="utf-8")
for variant in ("values", "values-night"):
    path = f"app/src/main/res/{variant}/themes.xml"
    pairs = (
        ('<item name="colorPrimary">@color/black</item>', '<item name="colorPrimary">@color/neon_red</item>'),
        ('<item name="colorPrimaryVariant">@color/black</item>', '<item name="colorPrimaryVariant">@color/neon_red_dim</item>'),
        ('<item name="android:windowBackground">@color/black</item>', '<item name="android:windowBackground">@color/neon_bg</item>'),
        ('<item name="extraKeysButtonActiveTextColor">@color/red_400</item>', '<item name="extraKeysButtonActiveTextColor">@color/neon_red</item>'),
        ('<item name="extraKeysButtonBackgroundColor">@color/black</item>', '<item name="extraKeysButtonBackgroundColor">@color/neon_surface</item>'),
        ('<item name="extraKeysButtonActiveBackgroundColor">@color/grey_500</item>', '<item name="extraKeysButtonActiveBackgroundColor">@color/neon_red_dim</item>'),
    )
    for old, new in pairs: replace(root, path, old, new)
    old = '<item name="termuxActivityDrawerBackground">@color/' + ("white" if variant == "values" else "black") + '</item>'
    replace(root, path, old, '<item name="termuxActivityDrawerBackground">@color/neon_surface</item>')
replace(root, "terminal-emulator/src/main/java/com/termux/terminal/TerminalColorScheme.java",
        '0xffffffff, 0xff000000, 0xffffffff};', '0xfff6e9ee, 0xff080a10, 0xffff315a};')
replace(root, "app/src/main/AndroidManifest.xml",
        'android:icon="@mipmap/ic_launcher"\n        android:label="@string/application_name"',
        'android:icon="@mipmap/neon_launcher"\n        android:label="@string/application_name"')
replace(root, "app/src/main/AndroidManifest.xml",
        'android:roundIcon="@mipmap/ic_launcher_round"', 'android:roundIcon="@mipmap/neon_launcher"')
from cairosvg import svg2png
for folder, size in (("mipmap-mdpi",48),("mipmap-hdpi",72),("mipmap-xhdpi",96),
                     ("mipmap-xxhdpi",144),("mipmap-xxxhdpi",192)):
    dest = root / "app/src/main/res" / folder / "neon_launcher.png"
    dest.parent.mkdir(exist_ok=True, parents=True)
    svg2png(bytestring=icon.read_bytes(), write_to=str(dest),
            output_width=size, output_height=size)
activity = "app/src/main/java/com/termux/app/TermuxActivity.java"
replace(root, activity, "import android.os.IBinder;\n",
        "import android.os.IBinder;\nimport android.os.Handler;\nimport android.os.Looper;\n"
        "import android.widget.TextView;\nimport java.util.List;\n"
        "import com.termux.shared.termux.shell.command.runner.terminal.TermuxSession;\n")
replace(root, activity, 'private static final int CONTEXT_MENU_REPORT_ID = 9;',
        'private static final int CONTEXT_MENU_REPORT_ID = 9;\n'
        '    private static final int CONTEXT_MENU_NEON_MONITOR_ID = 12;')
replace(root, activity,
        'menu.add(Menu.NONE, CONTEXT_MENU_REPORT_ID, Menu.NONE, R.string.action_report_issue);',
        'menu.add(Menu.NONE, CONTEXT_MENU_REPORT_ID, Menu.NONE, R.string.action_report_issue);\n'
        '        menu.add(Menu.NONE, CONTEXT_MENU_NEON_MONITOR_ID, Menu.NONE, "Monitor de sessões");')
replace(root, activity,
        'case CONTEXT_MENU_STYLING_ID:\n                showStylingDialog();',
        'case CONTEXT_MENU_NEON_MONITOR_ID:\n                showNeonMonitor();\n'
        '                return true;\n            case CONTEXT_MENU_STYLING_ID:\n'
        '                showStylingDialog();')
monitor = """
    /** Monitor current sessions; does not execute arbitrary commands. */
    private void showNeonMonitor() {
        final TextView status = new TextView(this);
        status.setPadding(40, 28, 40, 36);
        status.setTextColor(0xFFFFF2F4);
        status.setTextSize(15f);
        status.setBackgroundColor(0xFF151019);
        final Handler handler = new Handler(Looper.getMainLooper());
        final AlertDialog dialog = new AlertDialog.Builder(this)
            .setTitle("Neon Terminal • Monitor")
            .setView(status)
            .setPositiveButton("Fechar", null)
            .create();
        final Runnable refresh = new Runnable() {
            @Override public void run() {
                if (!dialog.isShowing()) return;
                StringBuilder out = new StringBuilder();
                if (mTermuxService == null) {
                    out.append("Aguardando serviço do terminal…");
                } else {
                    List<TermuxSession> sessions = mTermuxService.getTermuxSessions();
                    out.append("Sessões: ").append(sessions.size()).append("\\n\\n");
                    if (sessions.isEmpty()) out.append("Nenhuma sessão aberta");
                    for (int i = 0; i < sessions.size(); i++) {
                        TerminalSession s = sessions.get(i).getTerminalSession();
                        out.append(i + 1).append(". ");
                        out.append(s.mSessionName == null ? "Terminal" : s.mSessionName);
                        if (s == getCurrentSession()) out.append(" • atual");
                        out.append("\\nPID: ").append(s.getPid()).append(" • ");
                        out.append(s.isRunning() ? "executando" : "encerrada");
                        out.append("\\n\\n");
                    }
                }
                status.setText(out.toString());
                handler.postDelayed(this, 1500);
            }
        };
        dialog.setOnDismissListener(ignored -> handler.removeCallbacks(refresh));
        dialog.show();
        handler.post(refresh);
    }

"""
replace(root, activity, '    private void showStylingDialog() {',
        monitor + '    private void showStylingDialog() {')
print("Neon Terminal patch OK. Preserved original package ID com.termux.")
