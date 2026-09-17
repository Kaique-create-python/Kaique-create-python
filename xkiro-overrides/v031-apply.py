from pathlib import Path
root=Path('xkiro-ai-studio')
res=root/'app/src/main/res'
layout=res/'layout/activity_main.xml'
xml=layout.read_text()
marker='        <!-- Hidden operational controls kept alive; opened through the gear -->'
if marker not in xml:
    raise SystemExit('hidden controls marker missing')
tail=xml[xml.index(marker):]
front=r'''<ScrollView xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:fillViewport="true"
    android:background="@color/bg"
    android:clipToPadding="false"
    android:overScrollMode="never">

    <LinearLayout
        android:id="@+id/rootContent"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="vertical"
        android:paddingLeft="20dp"
        android:paddingTop="14dp"
        android:paddingRight="20dp"
        android:paddingBottom="26dp">

        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:gravity="top" android:orientation="horizontal">
            <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:orientation="vertical">
                <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:fontFamily="sans-serif-black" android:text="Diana" android:textColor="@color/text" android:textSize="31sp" />
                <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_marginTop="-2dp" android:fontFamily="sans-serif" android:text="assistente multiagente" android:textColor="@color/muted" android:textSize="12sp" />
                <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_marginTop="8dp" android:gravity="center_vertical" android:orientation="horizontal">
                    <View android:layout_width="8dp" android:layout_height="8dp" android:background="@drawable/diana_status_red" />
                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_marginLeft="7dp" android:text="Pronto" android:textColor="@color/textSecondary" android:textSize="12sp" />
                </LinearLayout>
            </LinearLayout>
            <LinearLayout android:layout_width="wrap_content" android:layout_height="wrap_content" android:gravity="top" android:orientation="horizontal">
                <LinearLayout android:layout_width="58dp" android:layout_height="wrap_content" android:gravity="center_horizontal" android:orientation="vertical">
                    <com.google.android.material.button.MaterialButton android:id="@+id/historyButton" style="@style/Widget.Material3.Button.TextButton" android:layout_width="46dp" android:layout_height="46dp" android:minWidth="0dp" android:insetLeft="0dp" android:insetRight="0dp" android:insetTop="0dp" android:insetBottom="0dp" android:padding="11dp" app:backgroundTint="@color/surfaceSoft" app:cornerRadius="23dp" app:icon="@drawable/ic_history" app:iconGravity="textStart" app:iconPadding="0dp" app:iconSize="23dp" app:iconTint="@color/textSecondary" />
                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_marginTop="2dp" android:text="Histórico" android:textColor="@color/muted" android:textSize="8.5sp" />
                </LinearLayout>
                <LinearLayout android:layout_width="68dp" android:layout_height="wrap_content" android:layout_marginLeft="4dp" android:gravity="center_horizontal" android:orientation="vertical">
                    <com.google.android.material.button.MaterialButton android:id="@+id/settingsButton" style="@style/Widget.Material3.Button.TextButton" android:layout_width="46dp" android:layout_height="46dp" android:minWidth="0dp" android:insetLeft="0dp" android:insetRight="0dp" android:insetTop="0dp" android:insetBottom="0dp" android:padding="11dp" app:backgroundTint="@color/surfaceSoft" app:cornerRadius="23dp" app:icon="@drawable/ic_settings" app:iconGravity="textStart" app:iconPadding="0dp" app:iconSize="23dp" app:iconTint="@color/textSecondary" />
                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_marginTop="2dp" android:text="Configurações" android:textColor="@color/muted" android:textSize="8.5sp" />
                </LinearLayout>
            </LinearLayout>
        </LinearLayout>

        <FrameLayout android:id="@+id/dianaOrb" android:layout_width="124dp" android:layout_height="124dp" android:layout_gravity="center_horizontal" android:layout_marginTop="4dp" android:background="@drawable/diana_orb_glow">
            <FrameLayout android:layout_width="112dp" android:layout_height="112dp" android:layout_gravity="center" android:background="@drawable/diana_orb">
                <ImageView android:layout_width="50dp" android:layout_height="50dp" android:layout_gravity="center" android:contentDescription="Diana" android:src="@drawable/diana_mark" />
            </FrameLayout>
        </FrameLayout>
        <TextView android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="4dp" android:fontFamily="sans-serif-medium" android:gravity="center" android:text="Olá! Eu sou a Diana." android:textColor="@color/text" android:textSize="20sp" />
        <TextView android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="3dp" android:gravity="center" android:text="Mais do que uma IA. Sua parceira para fazer acontecer." android:textColor="@color/muted" android:textSize="11.5sp" />

        <LinearLayout android:id="@+id/assistantCard" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="13dp" android:background="@drawable/diana_card" android:elevation="2dp" android:orientation="horizontal" android:padding="12dp">
            <FrameLayout android:layout_width="40dp" android:layout_height="40dp" android:background="@drawable/diana_icon_circle"><ImageView android:layout_width="22dp" android:layout_height="22dp" android:layout_gravity="center" android:contentDescription="Diana" android:src="@drawable/diana_mark" /></FrameLayout>
            <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_marginLeft="12dp" android:layout_weight="1" android:orientation="vertical">
                <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:gravity="center_vertical" android:orientation="horizontal">
                    <TextView android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:text="Diana" android:textColor="@color/dianaRed" android:textSize="11sp" />
                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="agora" android:textColor="@color/mutedDark" android:textSize="9.5sp" />
                </LinearLayout>
                <TextView android:id="@+id/output" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="5dp" android:text="Posso controlar seu aparelho, trabalhar em projetos e acompanhar a tela em tempo real." android:textColor="@color/text" android:textIsSelectable="true" android:textSize="14sp" android:lineSpacingExtra="1dp" />
                <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="6dp" android:gravity="center_vertical" android:orientation="horizontal">
                    <TextView android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:text="Sempre ao seu lado, do plano à execução." android:textColor="@color/muted" android:textSize="10.5sp" />
                    <ImageView android:layout_width="18dp" android:layout_height="18dp" android:contentDescription="Favorito" android:src="@drawable/ic_heart" app:tint="@color/muted" />
                </LinearLayout>
            </LinearLayout>
        </LinearLayout>

        <LinearLayout android:id="@+id/executionBar" android:layout_width="match_parent" android:layout_height="62dp" android:layout_marginTop="9dp" android:background="@drawable/diana_card" android:gravity="center_vertical" android:orientation="horizontal" android:paddingLeft="11dp" android:paddingRight="9dp">
            <FrameLayout android:layout_width="38dp" android:layout_height="38dp" android:background="@drawable/diana_icon_circle"><ImageView android:layout_width="20dp" android:layout_height="20dp" android:layout_gravity="center" android:src="@drawable/ic_monitor" app:tint="@color/textSecondary" /></FrameLayout>
            <View android:layout_width="8dp" android:layout_height="8dp" android:layout_marginLeft="9dp" android:background="@drawable/diana_status_red" />
            <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_marginLeft="9dp" android:layout_weight="1" android:orientation="vertical">
                <TextView android:id="@+id/runtimeStatus" android:layout_width="match_parent" android:layout_height="wrap_content" android:ellipsize="end" android:maxLines="1" android:text="Pronto para agir" android:textColor="@color/text" android:textSize="12sp" android:textStyle="bold" />
                <TextView android:id="@+id/screenVisionStatus" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="1dp" android:ellipsize="end" android:maxLines="1" android:text="Screen Vision • aguardando" android:textColor="@color/muted" android:textSize="9.5sp" />
            </LinearLayout>
            <com.google.android.material.button.MaterialButton android:id="@+id/viewExecution" style="@style/Widget.Material3.Button.OutlinedButton" android:layout_width="98dp" android:layout_height="38dp" android:minWidth="0dp" android:insetTop="0dp" android:insetBottom="0dp" android:text="Ver execução" android:textAllCaps="false" android:textColor="@color/text" android:textSize="10sp" app:cornerRadius="19dp" app:icon="@drawable/ic_chevron_right" app:iconGravity="textEnd" app:iconPadding="4dp" app:iconSize="15dp" app:iconTint="@color/muted" app:strokeColor="@color/border" />
        </LinearLayout>

        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="10dp" android:orientation="horizontal">
            <com.google.android.material.button.MaterialButton android:id="@+id/modeChat" style="@style/Widget.Material3.Button.OutlinedButton" android:layout_width="0dp" android:layout_height="46dp" android:layout_weight="1" android:minWidth="0dp" android:text="Chat" android:textAllCaps="false" android:textColor="@color/text" android:textSize="12sp" app:backgroundTint="@color/surfaceSoft" app:cornerRadius="23dp" app:icon="@drawable/ic_chat" app:iconPadding="7dp" app:iconSize="20dp" app:iconTint="@color/textSecondary" app:strokeColor="@color/border" />
            <com.google.android.material.button.MaterialButton android:id="@+id/modeWork" style="@style/Widget.Material3.Button.OutlinedButton" android:layout_width="0dp" android:layout_height="46dp" android:layout_marginLeft="8dp" android:layout_weight="1" android:minWidth="0dp" android:text="Work" android:textAllCaps="false" android:textColor="@color/text" android:textSize="12sp" app:backgroundTint="@color/surfaceSoft" app:cornerRadius="23dp" app:icon="@drawable/ic_work" app:iconPadding="7dp" app:iconSize="20dp" app:iconTint="@color/textSecondary" app:strokeColor="@color/border" />
            <com.google.android.material.button.MaterialButton android:id="@+id/modeDevice" style="@style/Widget.Material3.Button.OutlinedButton" android:layout_width="0dp" android:layout_height="46dp" android:layout_marginLeft="8dp" android:layout_weight="1" android:minWidth="0dp" android:text="Aparelho" android:textAllCaps="false" android:textColor="@color/dianaRed" android:textSize="12sp" app:backgroundTint="@color/redTint" app:cornerRadius="23dp" app:icon="@drawable/ic_phone" app:iconPadding="7dp" app:iconSize="19dp" app:iconTint="@color/dianaRed" app:strokeColor="@color/dianaRed" />
        </LinearLayout>

        <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="10dp" android:background="@drawable/diana_composer" android:orientation="vertical" android:paddingLeft="12dp" android:paddingTop="9dp" android:paddingRight="10dp" android:paddingBottom="8dp">
            <EditText android:id="@+id/prompt" android:layout_width="match_parent" android:layout_height="52dp" android:background="@android:color/transparent" android:gravity="top|start" android:hint="Peça qualquer coisa à Diana..." android:inputType="textMultiLine|textCapSentences" android:paddingLeft="2dp" android:paddingTop="2dp" android:paddingRight="2dp" android:textColor="@color/text" android:textColorHint="@color/muted" android:textSize="14sp" />
            <LinearLayout android:layout_width="match_parent" android:layout_height="48dp" android:gravity="center_vertical" android:orientation="horizontal">
                <com.google.android.material.button.MaterialButton android:id="@+id/analyzeImage" style="@style/Widget.Material3.Button.TextButton" android:layout_width="40dp" android:layout_height="40dp" android:minWidth="0dp" android:insetLeft="0dp" android:insetRight="0dp" android:insetTop="0dp" android:insetBottom="0dp" app:icon="@drawable/ic_attach" app:iconGravity="textStart" app:iconPadding="0dp" app:iconSize="22dp" app:iconTint="@color/textSecondary" />
                <com.google.android.material.button.MaterialButton android:id="@+id/startVoice" style="@style/Widget.Material3.Button.TextButton" android:layout_width="40dp" android:layout_height="40dp" android:layout_marginLeft="4dp" android:minWidth="0dp" android:insetLeft="0dp" android:insetRight="0dp" android:insetTop="0dp" android:insetBottom="0dp" app:icon="@drawable/ic_mic" app:iconGravity="textStart" app:iconPadding="0dp" app:iconSize="22dp" app:iconTint="@color/textSecondary" />
                <Space android:layout_width="0dp" android:layout_height="1dp" android:layout_weight="1" />
                <com.google.android.material.button.MaterialButton android:id="@+id/sendPrompt" android:layout_width="48dp" android:layout_height="48dp" android:minWidth="0dp" android:insetLeft="0dp" android:insetRight="0dp" android:insetTop="0dp" android:insetBottom="0dp" android:elevation="5dp" app:backgroundTint="@color/dianaRedDark" app:cornerRadius="24dp" app:icon="@drawable/ic_send" app:iconGravity="textStart" app:iconPadding="0dp" app:iconSize="23dp" app:iconTint="@color/text" />
            </LinearLayout>
        </LinearLayout>

        <LinearLayout android:id="@+id/devicePanel" android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="11dp" android:background="@drawable/diana_panel" android:orientation="vertical" android:padding="11dp">
            <LinearLayout android:layout_width="match_parent" android:layout_height="40dp" android:gravity="center_vertical" android:orientation="horizontal">
                <ImageView android:layout_width="24dp" android:layout_height="24dp" android:src="@drawable/ic_phone" app:tint="@color/textSecondary" />
                <TextView android:layout_width="0dp" android:layout_height="wrap_content" android:layout_marginLeft="10dp" android:layout_weight="1" android:text="Controle do aparelho" android:textColor="@color/text" android:textSize="13sp" android:textStyle="bold" />
                <TextView android:id="@+id/deviceCount" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="3/3 ativos" android:textColor="@color/muted" android:textSize="10sp" />
                <ImageView android:layout_width="18dp" android:layout_height="18dp" android:layout_marginLeft="5dp" android:src="@drawable/ic_chevron_down" app:tint="@color/muted" />
            </LinearLayout>
            <LinearLayout android:layout_width="match_parent" android:layout_height="56dp" android:layout_marginTop="3dp" android:background="@drawable/diana_row" android:gravity="center_vertical" android:orientation="horizontal" android:paddingLeft="10dp" android:paddingRight="4dp">
                <FrameLayout android:layout_width="36dp" android:layout_height="36dp" android:background="@drawable/diana_icon_circle"><ImageView android:layout_width="20dp" android:layout_height="20dp" android:layout_gravity="center" android:src="@drawable/ic_accessibility" app:tint="@color/textSecondary" /></FrameLayout>
                <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_marginLeft="9dp" android:layout_weight="1" android:orientation="vertical"><TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Acessibilidade" android:textColor="@color/text" android:textSize="12.5sp" /><TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Permite controle do sistema" android:textColor="@color/muted" android:textSize="9sp" /></LinearLayout>
                <View android:layout_width="7dp" android:layout_height="7dp" android:background="@drawable/status_dot" /><TextView android:id="@+id/accessibilityStatus" android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_marginLeft="6dp" android:text="verificando" android:textColor="@color/success" android:textSize="9.5sp" /><com.google.android.material.button.MaterialButton android:id="@+id/openAccessibility" style="@style/Widget.Material3.Button.TextButton" android:layout_width="34dp" android:layout_height="34dp" android:minWidth="0dp" android:insetLeft="0dp" android:insetRight="0dp" android:insetTop="0dp" android:insetBottom="0dp" app:icon="@drawable/ic_chevron_right" app:iconGravity="textStart" app:iconPadding="0dp" app:iconSize="17dp" app:iconTint="@color/muted" />
            </LinearLayout>
            <LinearLayout android:layout_width="match_parent" android:layout_height="56dp" android:layout_marginTop="5dp" android:background="@drawable/diana_row" android:gravity="center_vertical" android:orientation="horizontal" android:paddingLeft="10dp" android:paddingRight="4dp">
                <FrameLayout android:layout_width="36dp" android:layout_height="36dp" android:background="@drawable/diana_icon_circle"><ImageView android:layout_width="20dp" android:layout_height="20dp" android:layout_gravity="center" android:src="@drawable/ic_layers" app:tint="@color/textSecondary" /></FrameLayout>
                <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_marginLeft="9dp" android:layout_weight="1" android:orientation="vertical"><TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Shizuku" android:textColor="@color/text" android:textSize="12.5sp" /><TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Execução de comandos avançados" android:textColor="@color/muted" android:textSize="9sp" /></LinearLayout>
                <View android:layout_width="7dp" android:layout_height="7dp" android:background="@drawable/status_dot" /><TextView android:id="@+id/shizukuStatus" android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_marginLeft="6dp" android:text="verificando" android:textColor="@color/success" android:textSize="9.5sp" /><com.google.android.material.button.MaterialButton android:id="@+id/allowShizuku" style="@style/Widget.Material3.Button.TextButton" android:layout_width="34dp" android:layout_height="34dp" android:minWidth="0dp" android:insetLeft="0dp" android:insetRight="0dp" android:insetTop="0dp" android:insetBottom="0dp" app:icon="@drawable/ic_chevron_right" app:iconGravity="textStart" app:iconPadding="0dp" app:iconSize="17dp" app:iconTint="@color/muted" />
            </LinearLayout>
            <LinearLayout android:layout_width="match_parent" android:layout_height="56dp" android:layout_marginTop="5dp" android:background="@drawable/diana_row" android:gravity="center_vertical" android:orientation="horizontal" android:paddingLeft="10dp" android:paddingRight="4dp">
                <FrameLayout android:layout_width="36dp" android:layout_height="36dp" android:background="@drawable/diana_icon_circle"><ImageView android:layout_width="20dp" android:layout_height="20dp" android:layout_gravity="center" android:src="@drawable/ic_monitor" app:tint="@color/textSecondary" /></FrameLayout>
                <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_marginLeft="9dp" android:layout_weight="1" android:orientation="vertical"><TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Screen Vision" android:textColor="@color/text" android:textSize="12.5sp" /><TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Acompanha sua tela em tempo real" android:textColor="@color/muted" android:textSize="9sp" /></LinearLayout>
                <View android:layout_width="7dp" android:layout_height="7dp" android:background="@drawable/status_dot" /><TextView android:id="@+id/screenVisionRowStatus" android:layout_width="wrap_content" android:layout_height="wrap_content" android:layout_marginLeft="6dp" android:text="desligado" android:textColor="@color/muted" android:textSize="9.5sp" /><com.google.android.material.button.MaterialButton android:id="@+id/shareScreen" style="@style/Widget.Material3.Button.TextButton" android:layout_width="34dp" android:layout_height="34dp" android:minWidth="0dp" android:insetLeft="0dp" android:insetRight="0dp" android:insetTop="0dp" android:insetBottom="0dp" app:icon="@drawable/ic_chevron_right" app:iconGravity="textStart" app:iconPadding="0dp" app:iconSize="17dp" app:iconTint="@color/muted" />
            </LinearLayout>
        </LinearLayout>
        <TextView android:layout_width="match_parent" android:layout_height="wrap_content" android:layout_marginTop="13dp" android:gravity="center" android:letterSpacing="0.32" android:text="FOCO  •  AÇÃO  •  RESULTADOS" android:textColor="@color/mutedDark" android:textSize="7sp" />

'''
layout.write_text(front+tail)
files={
'drawable/diana_card.xml':'<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><gradient android:angle="270" android:startColor="#F317191C" android:endColor="#EE101215"/><stroke android:width="1dp" android:color="#34383F"/><corners android:radius="22dp"/></shape>',
'drawable/diana_composer.xml':'<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><gradient android:angle="270" android:startColor="#FA181A1E" android:endColor="#F7121417"/><stroke android:width="1dp" android:color="#353940"/><corners android:radius="24dp"/></shape>',
'drawable/diana_panel.xml':'<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><gradient android:angle="270" android:startColor="#F415171A" android:endColor="#F10E1012"/><stroke android:width="1dp" android:color="#30343A"/><corners android:radius="23dp"/></shape>',
'drawable/diana_row.xml':'<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle"><solid android:color="#D9181B1F"/><stroke android:width="1dp" android:color="#292D33"/><corners android:radius="17dp"/></shape>',
'drawable/diana_icon_circle.xml':'<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><gradient android:type="radial" android:gradientRadius="34dp" android:startColor="#252A30" android:endColor="#1A1D21"/><stroke android:width="1dp" android:color="#30343A"/></shape>',
'drawable/diana_orb.xml':'<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><gradient android:type="radial" android:gradientRadius="78dp" android:centerX="50%" android:centerY="42%" android:startColor="#492226" android:centerColor="#211417" android:endColor="#0B0D0F"/><stroke android:width="1.15dp" android:color="#FF5A61"/></shape>',
'drawable/diana_orb_glow.xml':'<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><gradient android:type="radial" android:gradientRadius="82dp" android:centerX="50%" android:centerY="50%" android:startColor="#4FFF575F" android:centerColor="#16FF575F" android:endColor="#00FF575F"/></shape>'}
for rel,data in files.items():
    p=res/rel; p.parent.mkdir(parents=True,exist_ok=True); p.write_text(data)
vectors={
'ic_history':('24','M13,3a9,9 0,1 0,8.95,10H20a7,7 0,1 1,-2.05,-4.95L15,11h7V4l-2.6,2.6A8.96,8.96 0,0 0,13,3z M12,7h2v5l4,2l-1,1.73L12,13V7z'),
'ic_settings':('24','M19.43,12.98c0.04,-0.32 0.07,-0.65 0.07,-0.98s-0.02,-0.66 -0.07,-0.98l2.11,-1.65c0.19,-0.15 0.24,-0.42 0.12,-0.64l-2,-3.46c-0.12,-0.22 -0.37,-0.31 -0.6,-0.22l-2.49,1a7.3,7.3 0,0 0,-1.69,-0.98L14.5,2.42A0.49,0.49 0,0 0,14,2h-4c-0.25,0 -0.46,0.18 -0.49,0.42L9.13,5.07c-0.61,0.25 -1.17,0.59 -1.69,0.98l-2.49,-1c-0.23,-0.08 -0.48,0 -0.6,0.22l-2,3.46c-0.13,0.22 -0.07,0.49 0.12,0.64l2.11,1.65c-0.04,0.32 -0.08,0.66 -0.08,0.98s0.03,0.66 0.08,0.98l-2.11,1.65c-0.19,0.15 -0.24,0.42 -0.12,0.64l2,3.46c0.12,0.22 0.37,0.31 0.6,0.22l2.49,-1c0.52,0.4 1.08,0.73 1.69,0.98l0.38,2.65c0.03,0.24 0.24,0.42 0.49,0.42h4c0.25,0 0.46,-0.18 0.49,-0.42l0.38,-2.65a7.3,7.3 0,0 0,1.69,-0.98l2.49,1c0.23,0.08 0.48,0 0.6,-0.22l2,-3.46c0.12,-0.22 0.07,-0.49 -0.12,-0.64l-2.11,-1.65z M12,15.5A3.5,3.5 0,1 1,12 8a3.5,3.5 0,0 1,0 7.5z'),
'ic_heart':('24','M12,21.35l-1.45,-1.32C5.4,15.36 2,12.28 2,8.5 2,5.42 4.42,3 7.5,3c1.74,0 3.41,0.81 4.5,2.09C13.09,3.81 14.76,3 16.5,3 19.58,3 22,5.42 22,8.5c0,3.78 -3.4,6.86 -8.55,11.54L12,21.35z'),
'ic_monitor':('24','M3,4h18c1.1,0 2,0.9 2,2v11c0,1.1 -0.9,2 -2,2h-7v2h3v2H7v-2h3v-2H3c-1.1,0 -2,-0.9 -2,-2V6c0,-1.1 0.9,-2 2,-2z M3,6v11h18V6H3z'),
'ic_chevron_right':('24','M9.29,6.71a1,1 0,0 1,1.42 0l4.58,4.58a1,1 0,0 1,0 1.42l-4.58,4.58a1,1 0,1 1,-1.42,-1.42L13.17,12 9.29,8.12a1,1 0,0 1,0 -1.41z'),
'ic_chevron_down':('24','M6.71,9.29a1,1 0,0 1,1.42 0L12,13.17l3.88,-3.88a1,1 0,1 1,1.42 1.42l-4.59,4.58a1,1 0,0 1,-1.42 0L6.71,10.71a1,1 0,0 1,0 -1.42z'),
'ic_chat':('24','M20,2H4a2,2 0,0 0,-2,2v18l4,-4h14a2,2 0,0 0,2,-2V4a2,2 0,0 0,-2,-2z M20,16H5.17L4,17.17V4h16v12z'),
'ic_work':('24','M20,6h-4V4a2,2 0,0 0,-2,-2h-4a2,2 0,0 0,-2,2v2H4a2,2 0,0 0,-2,2v11a2,2 0,0 0,2,2h16a2,2 0,0 0,2,-2V8a2,2 0,0 0,-2,-2z M10,4h4v2h-4V4z M20,19H4v-5h6v1h4v-1h6v5z M14,12h-4v1H4V8h16v5h-6v-1z'),
'ic_phone':('24','M17,1H7C5.9,1 5,1.9 5,3v18c0,1.1 0.9,2 2,2h10c1.1,0 2,-0.9 2,-2V3c0,-1.1 -0.9,-2 -2,-2z M17,19H7V5h10v14z M12,22a1,1 0,1 1,0 -2a1,1 0,0 1,0 2z'),
'ic_attach':('24','M16.5,6.5v9a4.5,4.5 0,0 1,-9,0V5a3.5,3.5 0,0 1,7,0v9.5a2.5,2.5 0,0 1,-5,0V6.5h2v8a0.5,0.5 0,0 0,1 0V5a1.5,1.5 0,0 0,-3,0v10.5a2.5,2.5 0,0 0,5 0v-9h2z'),
'ic_mic':('24','M12,14a3,3 0,0 0,3 -3V5a3,3 0,0 0,-6 0v6a3,3 0,0 0,3 3z M17.3,11a5.3,5.3 0,0 1,-10.6 0H5a7,7 0,0 0,6 6.92V21H8v2h8v-2h-3v-3.08A7,7 0,0 0,19 11h-1.7z'),
'ic_send':('24','M2.01,21L23,12 2.01,3 2,10l15,2 -15,2z'),
'ic_accessibility':('24','M12,2a2,2 0,1 1,0 4a2,2 0,0 1,0 -4z M19,9h-4v13h-2v-6h-2v6H9V9H5V7h14v2z'),
'ic_layers':('24','M12,2L1,7l11,5 9,-4.09V17h2V7L12,2z M1,12l11,5 7,-3.18v2.2L12,19.2 1,14.2V12z M1,17l11,5 7,-3.18V21l-7,3 -11,-5v-2z')}
for name,(vw,pathdata) in vectors.items():
    (res/f'drawable/{name}.xml').write_text(f'<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="{vw}" android:viewportHeight="24"><path android:fillColor="#FFFFFFFF" android:pathData="{pathdata}"/></vector>')
(res/'values/colors.xml').write_text('''<resources>\n    <color name="bg">#08090B</color>\n    <color name="surface">#111316</color>\n    <color name="surface2">#17191D</color>\n    <color name="surface3">#1B1E22</color>\n    <color name="surfaceSoft">#15171A</color>\n    <color name="composer">#15171A</color>\n    <color name="assistantBubble">#121417</color>\n    <color name="border">#34383F</color>\n    <color name="accent">#FF575F</color>\n    <color name="dianaRed">#FF575F</color>\n    <color name="dianaRedDark">#C93039</color>\n    <color name="redTint">#281316</color>\n    <color name="sendButton">#C93039</color>\n    <color name="sendText">#FFFFFF</color>\n    <color name="text">#F7F8FA</color>\n    <color name="textSecondary">#E2E4E8</color>\n    <color name="muted">#989EA8</color>\n    <color name="mutedDark">#666D77</color>\n    <color name="danger">#FF575F</color>\n    <color name="dangerText">#FF8B91</color>\n    <color name="dangerStroke">#6F2B31</color>\n    <color name="success">#35DF80</color>\n    <color name="successStroke">#28593E</color>\n</resources>''')
build=root/'app/build.gradle.kts'
s=build.read_text().replace('versionCode = 21','versionCode = 22').replace('versionName = "0.3.0"','versionName = "0.3.1"')
build.write_text(s)
main=root/'app/src/main/java/ai/xkiro/studio/MainActivity.kt'
s=main.read_text()
needle='''            duration = 360\n            start()\n        }\n    }'''
replacement='''            duration = 360\n            start()\n        }\n        findViewById<View>(R.id.dianaOrb)?.let { orb ->\n            ObjectAnimator.ofFloat(orb, View.SCALE_X, 1f, 1.025f).apply { duration = 1800; repeatCount = -1; repeatMode = 2; start() }\n            ObjectAnimator.ofFloat(orb, View.SCALE_Y, 1f, 1.025f).apply { duration = 1800; repeatCount = -1; repeatMode = 2; start() }\n        }\n    }'''
if needle not in s: raise SystemExit('animateEntrance marker missing')
main.write_text(s.replace(needle,replacement,1))
print('Applied Diana v0.3.1 pixel-match UI')