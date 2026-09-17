from pathlib import Path
root=Path("xkiro-ai-studio")

p=root/'app/src/main/res/layout/activity_main.xml'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('<ScrollView xmlns:android="http://schemas.android.com/apk/res/android"\n    xmlns:app="http://schemas.android.com/apk/res-auto"\n    android:layout_width="match_parent"\n    android:layout_height="match_parent"\n    android:fillViewport="true"\n    android:background="@color/bg"\n    android:clipToPadding="false">\n\n    <LinearLayout\n        android:id="@+id/rootContent"\n        android:layout_width="match_parent"\n        android:layout_height="wrap_content"\n        android:orientation="vertical"\n        android:paddingLeft="18dp"\n        android:paddingTop="18dp"\n        android:paddingRight="18dp"\n        android:paddingBottom="30dp">\n\n        <!-- Header -->\n        <LinearLayout\n            android:layout_width="match_parent"\n            android:layout_height="wrap_content"\n            android:gravity="top"\n            android:orientation="horizontal">\n\n            <LinearLayout\n                android:layout_width="0dp"\n                android:layout_height="wrap_content"\n                android:layout_weight="1"\n                android:orientation="vertical">\n\n                <TextView\n                    android:layout_width="wrap_content"\n                    android:layout_height="wrap_content"\n                    android:text="Diana"\n                    android:textColor="@color/text"\n                    android:textSize="30sp"\n                    android:textStyle="bold" />\n\n                <TextView\n                    android:layout_width="wrap_content"\n                    android:layout_height="wrap_content"\n                    android:layout_marginTop="1dp"\n                    android:text="assistente multiagente"\n                    android:textColor="@color/muted"\n                    android:textSize="13sp" />\n\n                <LinearLayout\n                    android:layout_width="wrap_content"\n                    android:layout_height="wrap_content"\n                    android:layout_marginTop="9dp"\n                    android:gravity="center_vertical"\n                    android:orientation="horizontal">\n\n                    <View\n                        android:layout_width="9dp"\n                        android:layout_height="9dp"\n                        android:background="@drawable/diana_status_red" />\n\n                    <TextView\n                        android:layout_width="wrap_content"\n                        android:layout_height="wrap_content"\n                        android:layout_marginLeft="8dp"\n                        android:text="Pronto"\n                        android:textColor="@color/textSecondary"\n                        android:textSize="13sp" />\n                </LinearLayout>\n            </LinearLayout>\n\n            <LinearLayout\n                android:layout_width="wrap_content"\n                android:layout_height="wrap_content"\n                android:gravity="center"\n                android:orientation="horizontal">\n\n                <com.google.android.material.button.MaterialButton\n                    android:id="@+id/historyButton"\n                    style="@style/Widget.Material3.Button.TextButton"\n                    android:layout_width="54dp"\n                    android:layout_height="54dp"\n                    android:minWidth="0dp"\n                    android:insetLeft="0dp"\n                    android:insetRight="0dp"\n                    android:insetTop="0dp"\n                    android:insetBottom="0dp"\n                    android:text="↶"\n                    android:textColor="@color/text"\n                    android:textSize="25sp"\n                    app:backgroundTint="@color/surfaceSoft"\n                    app:cornerRadius="27dp" />\n\n                <com.google.android.material.button.MaterialButton\n                    android:id="@+id/settingsButton"\n                    style="@style/Widget.Material3.Button.TextButton"\n                    android:layout_width="54dp"\n                    android:layout_height="54dp"\n                    android:layout_marginLeft="10dp"\n                    android:minWidth="0dp"\n                    android:insetLeft="0dp"\n                    android:insetRight="0dp"\n                    android:insetTop="0dp"\n                    android:insetBottom="0dp"\n                    android:text="⚙"\n                    android:textColor="@color/text"\n                    android:textSize="22sp"\n                    app:backgroundTint="@color/surfaceSoft"\n                    app:cornerRadius="27dp" />\n            </LinearLayout>\n        </LinearLayout>\n\n        <!-- Diana orb -->\n        <FrameLayout\n            android:layout_width="142dp"\n            android:layout_height="142dp"\n            android:layout_gravity="center_horizontal"\n            android:layout_marginTop="6dp"\n            android:background="@drawable/diana_orb">\n\n            <ImageView\n                android:layout_width="60dp"\n                android:layout_height="60dp"\n                android:layout_gravity="center"\n                android:contentDescription="Diana"\n                android:src="@drawable/diana_mark" />\n        </FrameLayout>\n\n        <TextView\n            android:layout_width="match_parent"\n            android:layout_height="wrap_content"\n            android:layout_marginTop="8dp"\n            android:gravity="center"\n            android:text="Olá! Eu sou a Diana."\n            android:textColor="@color/text"\n            android:textSize="22sp"\n            android:textStyle="bold" />\n\n        <TextView\n            android:layout_width="match_parent"\n            android:layout_height="wrap_content"\n            android:layout_marginTop="5dp"\n            android:gravity="center"\n            android:text="Mais do que uma IA. Sua parceira para fazer acontecer."\n            android:textColor="@color/muted"\n            android:textSize="13sp" />\n\n        <!-- Assistant message -->\n        <LinearLayout\n            android:id="@+id/assistantCard"\n            android:layout_width="match_parent"\n            android:layout_height="wrap_content"\n            android:layout_marginTop="18dp"\n            android:background="@drawable/diana_card"\n            android:elevation="2dp"\n            android:orientation="horizontal"\n            android:padding="15dp">\n\n            <FrameLayout\n                android:layout_width="44dp"\n                android:layout_height="44dp"\n                android:background="@drawable/diana_icon_circle">\n                <ImageView\n                    android:layout_width="24dp"\n                    android:layout_height="24dp"\n                    android:layout_gravity="center"\n                    android:contentDescription="Diana"\n                    android:src="@drawable/diana_mark" />\n            </FrameLayout>\n\n            <LinearLayout\n                android:layout_width="0dp"\n                android:layout_height="wrap_content"\n                android:layout_marginLeft="13dp"\n                android:layout_weight="1"\n                android:orientation="vertical">\n\n                <LinearLayout\n                    android:layout_width="match_parent"\n                    android:layout_height="wrap_content"\n                    android:gravity="center_vertical"\n                    android:orientation="horizontal">\n                    <TextView\n                        android:layout_width="0dp"\n                        android:layout_height="wrap_content"\n                        android:layout_weight="1"\n                        android:text="Diana"\n                        android:textColor="@color/dianaRed"\n                        android:textSize="12sp" />\n                    <TextView\n                        android:layout_width="wrap_content"\n                        android:layout_height="wrap_content"\n                        android:text="agora"\n                        android:textColor="@color/mutedDark"\n                        android:textSize="11sp" />\n                </LinearLayout>\n\n                <TextView\n                    android:id="@+id/output"\n                    android:layout_width="match_parent"\n                    android:layout_height="wrap_content"\n                    android:layout_marginTop="7dp"\n                    android:minHeight="56dp"\n                    android:text="Posso controlar seu aparelho, trabalhar em projetos e acompanhar a tela em tempo real."\n                    android:textColor="@color/text"\n                    android:textIsSelectable="true"\n                    android:textSize="16sp"\n                    android:lineSpacingExtra="2dp" />\n\n                <TextView\n                    android:layout_width="match_parent"\n                    android:layout_height="wrap_content"\n                    android:layout_marginTop="7dp"\n                    android:text="Sempre ao seu lado, do plano à execução."\n                    android:textColor="@color/muted"\n                    android:textSize="12sp" />\n            </LinearLayout>\n        </LinearLayout>\n\n        <!-- Live execution bar -->\n        <LinearLayout\n            android:id="@+id/executionBar"\n            android:layout_width="match_parent"\n            android:layout_height="74dp"\n            android:layout_marginTop="10dp"\n            android:background="@drawable/diana_card"\n            android:gravity="center_vertical"\n            android:orientation="horizontal"\n            android:paddingLeft="13dp"\n            android:paddingRight="10dp">\n\n            <TextView\n                android:layout_width="40dp"\n                android:layout_height="40dp"\n                android:background="@drawable/diana_icon_circle"\n                android:gravity="center"\n                android:text="▣"\n                android:textColor="@color/text"\n                android:textSize="18sp" />\n\n            <View\n                android:layout_width="8dp"\n                android:layout_height="8dp"\n                android:layout_marginLeft="10dp"\n                android:background="@drawable/diana_status_red" />\n\n            <LinearLayout\n                android:layout_width="0dp"\n                android:layout_height="wrap_content"\n                android:layout_marginLeft="10dp"\n                android:layout_weight="1"\n                android:orientation="vertical">\n\n                <TextView\n                    android:id="@+id/runtimeStatus"\n                    android:layout_width="match_parent"\n                    android:layout_height="wrap_content"\n                    android:ellipsize="end"\n                    android:maxLines="1"\n                    android:text="Pronto para agir"\n                    android:textColor="@color/text"\n                    android:textSize="13sp"\n                    android:textStyle="bold" />\n\n                <TextView\n                    android:id="@+id/screenVisionStatus"\n                    android:layout_width="match_parent"\n                    android:layout_height="wrap_content"\n                    android:layout_marginTop="2dp"\n                    android:ellipsize="end"\n                    android:maxLines="1"\n                    android:text="Screen Vision • aguardando"\n                    android:textColor="@color/muted"\n                    android:textSize="11sp" />\n            </LinearLayout>\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/viewExecution"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="108dp"\n                android:layout_height="42dp"\n                android:text="Ver execução"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                android:textSize="11sp"\n                app:cornerRadius="21dp"\n                app:strokeColor="@color/border" />\n        </LinearLayout>\n\n        <!-- Modes -->\n        <LinearLayout\n            android:layout_width="match_parent"\n            android:layout_height="wrap_content"\n            android:layout_marginTop="12dp"\n            android:orientation="horizontal">\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/modeChat"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="0dp"\n                android:layout_height="50dp"\n                android:layout_weight="1"\n                android:text="◯  Chat"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:backgroundTint="@color/surfaceSoft"\n                app:cornerRadius="25dp"\n                app:strokeColor="@color/border" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/modeWork"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="0dp"\n                android:layout_height="50dp"\n                android:layout_marginLeft="8dp"\n                android:layout_weight="1"\n                android:text="▣  Work"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:backgroundTint="@color/surfaceSoft"\n                app:cornerRadius="25dp"\n                app:strokeColor="@color/border" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/modeDevice"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="0dp"\n                android:layout_height="50dp"\n                android:layout_marginLeft="8dp"\n                android:layout_weight="1"\n                android:text="▯  Aparelho"\n                android:textAllCaps="false"\n                android:textColor="@color/dianaRed"\n                app:backgroundTint="@color/redTint"\n                app:cornerRadius="25dp"\n                app:strokeColor="@color/dianaRed" />\n        </LinearLayout>\n\n        <!-- Composer -->\n        <LinearLayout\n            android:layout_width="match_parent"\n            android:layout_height="wrap_content"\n            android:layout_marginTop="12dp"\n            android:background="@drawable/diana_composer"\n            android:orientation="vertical"\n            android:padding="12dp">\n\n            <EditText\n                android:id="@+id/prompt"\n                android:layout_width="match_parent"\n                android:layout_height="78dp"\n                android:background="@android:color/transparent"\n                android:gravity="top|start"\n                android:hint="Peça qualquer coisa à Diana..."\n                android:inputType="textMultiLine|textCapSentences"\n                android:paddingLeft="4dp"\n                android:paddingTop="4dp"\n                android:paddingRight="4dp"\n                android:textColor="@color/text"\n                android:textColorHint="@color/muted"\n                android:textSize="15sp" />\n\n            <LinearLayout\n                android:layout_width="match_parent"\n                android:layout_height="wrap_content"\n                android:gravity="center_vertical"\n                android:orientation="horizontal">\n\n                <com.google.android.material.button.MaterialButton\n                    android:id="@+id/analyzeImage"\n                    style="@style/Widget.Material3.Button.TextButton"\n                    android:layout_width="44dp"\n                    android:layout_height="44dp"\n                    android:minWidth="0dp"\n                    android:text="⌕"\n                    android:textColor="@color/text"\n                    android:textSize="20sp" />\n\n                <com.google.android.material.button.MaterialButton\n                    android:id="@+id/startVoice"\n                    style="@style/Widget.Material3.Button.TextButton"\n                    android:layout_width="44dp"\n                    android:layout_height="44dp"\n                    android:minWidth="0dp"\n                    android:text="♪"\n                    android:textColor="@color/text"\n                    android:textSize="19sp" />\n\n                <Space\n                    android:layout_width="0dp"\n                    android:layout_height="1dp"\n                    android:layout_weight="1" />\n\n                <com.google.android.material.button.MaterialButton\n                    android:id="@+id/sendPrompt"\n                    android:layout_width="52dp"\n                    android:layout_height="52dp"\n                    android:minWidth="0dp"\n                    android:text="➤"\n                    android:textColor="@color/text"\n                    android:textSize="21sp"\n                    app:backgroundTint="@color/dianaRedDark"\n                    app:cornerRadius="26dp" />\n            </LinearLayout>\n        </LinearLayout>\n\n        <!-- Device control -->\n        <LinearLayout\n            android:id="@+id/devicePanel"\n            android:layout_width="match_parent"\n            android:layout_height="wrap_content"\n            android:layout_marginTop="13dp"\n            android:background="@drawable/diana_panel"\n            android:orientation="vertical"\n            android:padding="12dp">\n\n            <LinearLayout\n                android:layout_width="match_parent"\n                android:layout_height="44dp"\n                android:gravity="center_vertical"\n                android:orientation="horizontal">\n                <TextView\n                    android:layout_width="34dp"\n                    android:layout_height="34dp"\n                    android:background="@drawable/diana_icon_circle"\n                    android:gravity="center"\n                    android:text="▯"\n                    android:textColor="@color/text"\n                    android:textSize="16sp" />\n                <TextView\n                    android:layout_width="0dp"\n                    android:layout_height="wrap_content"\n                    android:layout_marginLeft="10dp"\n                    android:layout_weight="1"\n                    android:text="Controle do aparelho"\n                    android:textColor="@color/text"\n                    android:textSize="15sp"\n                    android:textStyle="bold" />\n                <TextView\n                    android:id="@+id/deviceCount"\n                    android:layout_width="wrap_content"\n                    android:layout_height="wrap_content"\n                    android:text="3/3 ativos"\n                    android:textColor="@color/muted"\n                    android:textSize="11sp" />\n            </LinearLayout>\n\n            <LinearLayout\n                android:layout_width="match_parent"\n                android:layout_height="64dp"\n                android:layout_marginTop="4dp"\n                android:background="@drawable/diana_row"\n                android:gravity="center_vertical"\n                android:orientation="horizontal"\n                android:paddingLeft="12dp"\n                android:paddingRight="6dp">\n                <TextView\n                    android:layout_width="38dp"\n                    android:layout_height="38dp"\n                    android:background="@drawable/diana_icon_circle"\n                    android:gravity="center"\n                    android:text="✦"\n                    android:textColor="@color/text"\n                    android:textSize="18sp" />\n                <LinearLayout\n                    android:layout_width="0dp"\n                    android:layout_height="wrap_content"\n                    android:layout_marginLeft="10dp"\n                    android:layout_weight="1"\n                    android:orientation="vertical">\n                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Acessibilidade" android:textColor="@color/text" android:textSize="14sp" />\n                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Permite controle do sistema" android:textColor="@color/muted" android:textSize="10sp" />\n                </LinearLayout>\n                <TextView\n                    android:id="@+id/accessibilityStatus"\n                    android:layout_width="wrap_content"\n                    android:layout_height="wrap_content"\n                    android:text="verificando"\n                    android:textColor="@color/success"\n                    android:textSize="10sp" />\n                <com.google.android.material.button.MaterialButton\n                    android:id="@+id/openAccessibility"\n                    style="@style/Widget.Material3.Button.TextButton"\n                    android:layout_width="38dp"\n                    android:layout_height="38dp"\n                    android:minWidth="0dp"\n                    android:text="›"\n                    android:textColor="@color/muted"\n                    android:textSize="22sp" />\n            </LinearLayout>\n\n            <LinearLayout\n                android:layout_width="match_parent"\n                android:layout_height="64dp"\n                android:layout_marginTop="7dp"\n                android:background="@drawable/diana_row"\n                android:gravity="center_vertical"\n                android:orientation="horizontal"\n                android:paddingLeft="12dp"\n                android:paddingRight="6dp">\n                <TextView\n                    android:layout_width="38dp"\n                    android:layout_height="38dp"\n                    android:background="@drawable/diana_icon_circle"\n                    android:gravity="center"\n                    android:text="≋"\n                    android:textColor="@color/text"\n                    android:textSize="20sp" />\n                <LinearLayout\n                    android:layout_width="0dp"\n                    android:layout_height="wrap_content"\n                    android:layout_marginLeft="10dp"\n                    android:layout_weight="1"\n                    android:orientation="vertical">\n                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Shizuku" android:textColor="@color/text" android:textSize="14sp" />\n                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Execução de comandos avançados" android:textColor="@color/muted" android:textSize="10sp" />\n                </LinearLayout>\n                <TextView\n                    android:id="@+id/shizukuStatus"\n                    android:layout_width="wrap_content"\n                    android:layout_height="wrap_content"\n                    android:text="verificando"\n                    android:textColor="@color/success"\n                    android:textSize="10sp" />\n                <com.google.android.material.button.MaterialButton\n                    android:id="@+id/allowShizuku"\n                    style="@style/Widget.Material3.Button.TextButton"\n                    android:layout_width="38dp"\n                    android:layout_height="38dp"\n                    android:minWidth="0dp"\n                    android:text="›"\n                    android:textColor="@color/muted"\n                    android:textSize="22sp" />\n            </LinearLayout>\n\n            <LinearLayout\n                android:layout_width="match_parent"\n                android:layout_height="64dp"\n                android:layout_marginTop="7dp"\n                android:background="@drawable/diana_row"\n                android:gravity="center_vertical"\n                android:orientation="horizontal"\n                android:paddingLeft="12dp"\n                android:paddingRight="6dp">\n                <TextView\n                    android:layout_width="38dp"\n                    android:layout_height="38dp"\n                    android:background="@drawable/diana_icon_circle"\n                    android:gravity="center"\n                    android:text="▣"\n                    android:textColor="@color/text"\n                    android:textSize="16sp" />\n                <LinearLayout\n                    android:layout_width="0dp"\n                    android:layout_height="wrap_content"\n                    android:layout_marginLeft="10dp"\n                    android:layout_weight="1"\n                    android:orientation="vertical">\n                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Screen Vision" android:textColor="@color/text" android:textSize="14sp" />\n                    <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Acompanha sua tela em tempo real" android:textColor="@color/muted" android:textSize="10sp" />\n                </LinearLayout>\n                <TextView\n                    android:id="@+id/screenVisionRowStatus"\n                    android:layout_width="wrap_content"\n                    android:layout_height="wrap_content"\n                    android:text="desligado"\n                    android:textColor="@color/muted"\n                    android:textSize="10sp" />\n                <com.google.android.material.button.MaterialButton\n                    android:id="@+id/shareScreen"\n                    style="@style/Widget.Material3.Button.TextButton"\n                    android:layout_width="38dp"\n                    android:layout_height="38dp"\n                    android:minWidth="0dp"\n                    android:text="›"\n                    android:textColor="@color/muted"\n                    android:textSize="22sp" />\n            </LinearLayout>\n        </LinearLayout>\n\n        <TextView\n            android:layout_width="match_parent"\n            android:layout_height="wrap_content"\n            android:layout_marginTop="18dp"\n            android:gravity="center"\n            android:letterSpacing="0.32"\n            android:text="FOCO  •  AÇÃO  •  RESULTADOS"\n            android:textColor="@color/mutedDark"\n            android:textSize="8sp" />\n\n        <!-- Hidden operational controls kept alive; opened through the gear -->\n        <LinearLayout\n            android:id="@+id/settingsPanel"\n            android:layout_width="match_parent"\n            android:layout_height="wrap_content"\n            android:layout_marginTop="16dp"\n            android:background="@drawable/diana_panel"\n            android:orientation="vertical"\n            android:padding="14dp"\n            android:visibility="gone">\n\n            <TextView\n                android:layout_width="match_parent"\n                android:layout_height="wrap_content"\n                android:text="Central da Diana"\n                android:textColor="@color/text"\n                android:textSize="18sp"\n                android:textStyle="bold" />\n\n            <TextView\n                android:id="@+id/doctorStatus"\n                android:layout_width="match_parent"\n                android:layout_height="wrap_content"\n                android:layout_marginTop="10dp"\n                android:text="Doctor: monitorando"\n                android:textColor="@color/success"\n                android:textSize="12sp" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/runDoctor"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:layout_marginTop="8dp"\n                android:text="Executar diagnóstico"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:cornerRadius="18dp"\n                app:strokeColor="@color/border" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/prepareTermux"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:text="Preparar Termux"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:cornerRadius="18dp"\n                app:strokeColor="@color/border" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/testScreenVision"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:text="Testar Screen Vision"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:cornerRadius="18dp"\n                app:strokeColor="@color/border" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/stopScreen"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:text="Parar Screen Vision"\n                android:textAllCaps="false"\n                android:textColor="@color/dianaRed"\n                app:cornerRadius="18dp"\n                app:strokeColor="@color/dianaRedDark" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/stopVoice"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:text="Parar voz"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:cornerRadius="18dp"\n                app:strokeColor="@color/border" />\n\n            <TextView\n                android:id="@+id/modelsText"\n                android:layout_width="match_parent"\n                android:layout_height="wrap_content"\n                android:layout_marginTop="14dp"\n                android:text="Modelos ainda não carregados."\n                android:textColor="@color/muted"\n                android:textSize="12sp" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/researchWeb"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:text="Pesquisar na internet"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:cornerRadius="18dp"\n                app:strokeColor="@color/border" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/refreshModels"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:text="Modelos e gasto"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:cornerRadius="18dp"\n                app:strokeColor="@color/border" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/swarmDemo"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:text="Testar assistente"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:cornerRadius="18dp"\n                app:strokeColor="@color/border" />\n\n            <TextView\n                android:id="@+id/workStatus"\n                android:layout_width="match_parent"\n                android:layout_height="wrap_content"\n                android:layout_marginTop="14dp"\n                android:text="Work: nenhum workspace."\n                android:textColor="@color/muted"\n                android:textSize="12sp" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/runWork"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:text="Executar Work"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:cornerRadius="18dp"\n                app:strokeColor="@color/border" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/exportWork"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:text="Exportar Work (.zip)"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:cornerRadius="18dp"\n                app:strokeColor="@color/border" />\n\n            <EditText\n                android:id="@+id/openRouterKey"\n                android:layout_width="match_parent"\n                android:layout_height="52dp"\n                android:layout_marginTop="14dp"\n                android:background="@drawable/diana_input"\n                android:hint="OpenRouter API key"\n                android:inputType="textPassword"\n                android:paddingLeft="14dp"\n                android:paddingRight="14dp"\n                android:textColor="@color/text"\n                android:textColorHint="@color/muted" />\n\n            <LinearLayout\n                android:layout_width="match_parent"\n                android:layout_height="wrap_content"\n                android:layout_marginTop="8dp"\n                android:orientation="horizontal">\n                <EditText\n                    android:id="@+id/dailyBudget"\n                    android:layout_width="0dp"\n                    android:layout_height="52dp"\n                    android:layout_weight="1"\n                    android:background="@drawable/diana_input"\n                    android:hint="US$ / dia"\n                    android:inputType="numberDecimal"\n                    android:paddingLeft="14dp"\n                    android:paddingRight="10dp"\n                    android:textColor="@color/text"\n                    android:textColorHint="@color/muted" />\n                <EditText\n                    android:id="@+id/taskBudget"\n                    android:layout_width="0dp"\n                    android:layout_height="52dp"\n                    android:layout_marginLeft="8dp"\n                    android:layout_weight="1"\n                    android:background="@drawable/diana_input"\n                    android:hint="US$ / tarefa"\n                    android:inputType="numberDecimal"\n                    android:paddingLeft="14dp"\n                    android:paddingRight="10dp"\n                    android:textColor="@color/text"\n                    android:textColorHint="@color/muted" />\n            </LinearLayout>\n\n            <EditText\n                android:id="@+id/xkiroKey"\n                android:layout_width="match_parent"\n                android:layout_height="52dp"\n                android:layout_marginTop="8dp"\n                android:background="@drawable/diana_input"\n                android:hint="xKiro API key (fallback)"\n                android:inputType="textPassword"\n                android:paddingLeft="14dp"\n                android:paddingRight="14dp"\n                android:textColor="@color/text"\n                android:textColorHint="@color/muted" />\n\n            <EditText\n                android:id="@+id/voiceKey"\n                android:layout_width="match_parent"\n                android:layout_height="52dp"\n                android:layout_marginTop="8dp"\n                android:background="@drawable/diana_input"\n                android:hint="ElevenLabs API key"\n                android:inputType="textPassword"\n                android:paddingLeft="14dp"\n                android:paddingRight="14dp"\n                android:textColor="@color/text"\n                android:textColorHint="@color/muted" />\n\n            <EditText\n                android:id="@+id/voiceId"\n                android:layout_width="match_parent"\n                android:layout_height="52dp"\n                android:layout_marginTop="8dp"\n                android:background="@drawable/diana_input"\n                android:hint="Voice ID"\n                android:paddingLeft="14dp"\n                android:paddingRight="14dp"\n                android:textColor="@color/text"\n                android:textColorHint="@color/muted" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/testVoice"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:text="Testar voz"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:cornerRadius="18dp"\n                app:strokeColor="@color/border" />\n\n            <EditText\n                android:id="@+id/wakeWord"\n                android:layout_width="match_parent"\n                android:layout_height="52dp"\n                android:layout_marginTop="8dp"\n                android:background="@drawable/diana_input"\n                android:hint="Nome para chamar a IA"\n                android:paddingLeft="14dp"\n                android:paddingRight="14dp"\n                android:textColor="@color/text"\n                android:textColorHint="@color/muted" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/saveSettings"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:layout_marginTop="10dp"\n                android:text="Salvar configurações"\n                android:textAllCaps="false"\n                android:textColor="@color/text"\n                app:backgroundTint="@color/dianaRedDark"\n                app:cornerRadius="18dp" />\n\n            <com.google.android.material.button.MaterialButton\n                android:id="@+id/stopEverything"\n                style="@style/Widget.Material3.Button.OutlinedButton"\n                android:layout_width="match_parent"\n                android:layout_height="48dp"\n                android:layout_marginTop="12dp"\n                android:text="Parar tudo"\n                android:textAllCaps="false"\n                android:textColor="@color/dianaRed"\n                app:cornerRadius="18dp"\n                app:strokeColor="@color/dianaRedDark" />\n        </LinearLayout>\n\n        <com.google.android.material.button.MaterialButton\n            android:id="@+id/stopTask"\n            style="@style/Widget.Material3.Button.TextButton"\n            android:layout_width="1dp"\n            android:layout_height="1dp"\n            android:visibility="gone"\n            android:text="Interromper" />\n    </LinearLayout>\n</ScrollView>\n')

p=root/'app/src/main/res/values/colors.xml'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('<resources>\n    <color name="bg">#090A0C</color>\n    <color name="surface">#121417</color>\n    <color name="surface2">#17191D</color>\n    <color name="surface3">#1B1E22</color>\n    <color name="surfaceSoft">#15171A</color>\n    <color name="composer">#15171A</color>\n    <color name="assistantBubble">#121417</color>\n    <color name="border">#34383E</color>\n    <color name="accent">#FF5B5B</color>\n    <color name="dianaRed">#FF5B5B</color>\n    <color name="dianaRedDark">#B92F35</color>\n    <color name="redTint">#251214</color>\n    <color name="sendButton">#B92F35</color>\n    <color name="sendText">#FFFFFF</color>\n    <color name="text">#F7F7F8</color>\n    <color name="textSecondary">#D3D5D8</color>\n    <color name="muted">#969BA3</color>\n    <color name="mutedDark">#666C75</color>\n    <color name="danger">#FF5B5B</color>\n    <color name="dangerText">#FF8B8B</color>\n    <color name="dangerStroke">#6F2B31</color>\n    <color name="success">#37DE83</color>\n    <color name="successStroke">#28593E</color>\n</resources>\n')

p=root/'app/src/main/res/drawable/diana_card.xml'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n    <solid android:color="#E6121417" />\n    <stroke android:width="1dp" android:color="#34383E" />\n    <corners android:radius="22dp" />\n</shape>\n')

p=root/'app/src/main/res/drawable/diana_panel.xml'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n    <solid android:color="#F0121417" />\n    <stroke android:width="1dp" android:color="#2E3238" />\n    <corners android:radius="24dp" />\n</shape>\n')

p=root/'app/src/main/res/drawable/diana_row.xml'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n    <solid android:color="#171A1E" />\n    <stroke android:width="1dp" android:color="#292D33" />\n    <corners android:radius="18dp" />\n</shape>\n')

p=root/'app/src/main/res/drawable/diana_composer.xml'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n    <solid android:color="#15171A" />\n    <stroke android:width="1dp" android:color="#34383E" />\n    <corners android:radius="24dp" />\n</shape>\n')

p=root/'app/src/main/res/drawable/diana_input.xml'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n    <solid android:color="#101215" />\n    <stroke android:width="1dp" android:color="#34383E" />\n    <corners android:radius="14dp" />\n</shape>\n')

p=root/'app/src/main/res/drawable/diana_icon_circle.xml'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">\n    <solid android:color="#1E2126" />\n    <stroke android:width="1dp" android:color="#2C3036" />\n</shape>\n')

p=root/'app/src/main/res/drawable/diana_status_red.xml'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">\n    <solid android:color="#FF5158" />\n</shape>\n')

p=root/'app/src/main/res/drawable/diana_orb.xml'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval">\n    <gradient\n        android:type="radial"\n        android:gradientRadius="80dp"\n        android:centerX="50%"\n        android:centerY="50%"\n        android:startColor="#3A181A"\n        android:centerColor="#181113"\n        android:endColor="#0C0D0F" />\n    <stroke android:width="1.5dp" android:color="#FF5B5B" />\n</shape>\n')

p=root/'app/src/main/res/drawable/diana_mark.xml'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('<vector xmlns:android="http://schemas.android.com/apk/res/android"\n    android:width="64dp"\n    android:height="64dp"\n    android:viewportWidth="64"\n    android:viewportHeight="64">\n    <path\n        android:fillColor="@android:color/transparent"\n        android:strokeColor="#FF5B5B"\n        android:strokeWidth="5"\n        android:strokeLineCap="round"\n        android:strokeLineJoin="round"\n        android:pathData="M32,9 L52,47 Q54,52 48,50 L32,42 L16,50 Q10,52 12,47 Z" />\n    <path\n        android:fillColor="@android:color/transparent"\n        android:strokeColor="#FF5B5B"\n        android:strokeWidth="5"\n        android:strokeLineCap="round"\n        android:strokeLineJoin="round"\n        android:pathData="M18,46 L32,20 L46,46" />\n</vector>\n')

p=root/'app/src/main/java/ai/xkiro/studio/MainActivity.kt'
p.parent.mkdir(parents=True,exist_ok=True)
p.write_text('''package ai.xkiro.studio

import android.Manifest
import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.graphics.BitmapFactory
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import ai.xkiro.studio.core.*
import ai.xkiro.studio.device.DeviceAgentController
import ai.xkiro.studio.device.ScreenCaptureService
import ai.xkiro.studio.device.ShizukuBridge
import ai.xkiro.studio.device.TermuxBridge
import ai.xkiro.studio.device.StudioAccessibilityService
import ai.xkiro.studio.doctor.DoctorEngine
import ai.xkiro.studio.openrouter.OpenRouterBudget
import ai.xkiro.studio.openrouter.OpenRouterOrchestrator
import ai.xkiro.studio.voice.VoiceAssistantService
import ai.xkiro.studio.voice.ElevenVoiceClient
import ai.xkiro.studio.work.WorkEngine
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.Locale

class MainActivity : AppCompatActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var activeTask: Job? = null
    private var utilityTask: Job? = null
    private var screenHealthTask: Job? = null
    private var testVoicePlayer: MediaPlayer? = null
    private var pendingDeviceCommand: String? = null

    private lateinit var store: SettingsStore
    private lateinit var out: TextView
    private lateinit var modelsText: TextView
    private lateinit var workStatus: TextView
    private lateinit var shizukuStatus: TextView
    private lateinit var accessibilityStatus: TextView
    private lateinit var doctorStatus: TextView
    private lateinit var runtimeStatus: TextView
    private lateinit var assistantCard: View
    private lateinit var openRouterKey: EditText
    private lateinit var dailyBudget: EditText
    private lateinit var taskBudget: EditText
    private lateinit var xKey: EditText
    private lateinit var vKey: EditText
    private lateinit var vId: EditText
    private lateinit var wake: EditText
    private lateinit var prompt: EditText

    private val micPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (ok) startVoiceService() else toast("Microfone não autorizado.")
    }

    private val termuxPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
        if (ok) {
            ShizukuBridge.connectUserService()
            toast("Permissão do Termux concedida. Vou concluir a preparação.")
            prepareTermux()
        } else toast("Permissão para executar comandos no Termux não concedida.")
    }

    private val capturePermission = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK && result.data != null) {
            val permissionData=result.data!!; val resultCode=result.resultCode
            runtimeStatus.text="Reiniciando Screen Vision…"
            scope.launch {
                stopService(Intent(this@MainActivity,ScreenCaptureService::class.java))
                val deadline=System.currentTimeMillis()+1500L
                while(ScreenCaptureService.active && System.currentTimeMillis()<deadline) delay(80)
                delay(120)
                val i=Intent(this@MainActivity,ScreenCaptureService::class.java).putExtra(ScreenCaptureService.EXTRA_RESULT_CODE,resultCode).putExtra(ScreenCaptureService.EXTRA_DATA,permissionData)
                ContextCompat.startForegroundService(this@MainActivity,i)
                runtimeStatus.text="Screen Vision: aguardando primeiro quadro…"
                val until=System.currentTimeMillis()+5000L
                while(!ScreenCaptureService.isStreaming() && System.currentTimeMillis()<until){ delay(250); runtimeStatus.text="Screen Vision: ${ScreenCaptureService.healthText()}"; updateScreenVisionButton() }
                if(ScreenCaptureService.isStreaming()){
                    runtimeStatus.text="Screen Vision: ${ScreenCaptureService.healthText()}"; updateScreenVisionButton()
                    val pending=pendingDeviceCommand; pendingDeviceCommand=null
                    if(!pending.isNullOrBlank()){ delay(220); runDevicePrompt(pending,currentSettings()) }
                } else { runtimeStatus.text="Screen Vision sem vídeo • ${ScreenCaptureService.healthText()}"; out.text="A autorização foi aceita, mas não chegaram quadros da tela. Toque em compartilhar tela novamente." }
            }
            toast("Permissão recebida. Validando vídeo real do Screen Vision.")
        } else { pendingDeviceCommand=null; runtimeStatus.text="Compartilhamento de tela não autorizado"; updateScreenVisionButton() }
    }

    private val pickImage = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@registerForActivityResult
        val settings = currentSettings()
        if (settings.openRouterKey.isBlank() && settings.xkiroKey.isBlank()) {
            toast("Configure OpenRouter ou xKiro primeiro.")
            return@registerForActivityResult
        }
        beginTask("Analisando imagem") {
            val jpeg = contentResolver.openInputStream(uri)?.use { input ->
                val bitmap = BitmapFactory.decodeStream(input) ?: error("Não consegui decodificar essa imagem.")
                val maxSide = maxOf(bitmap.width, bitmap.height).coerceAtLeast(1)
                val scaled = if (maxSide > 1600) {
                    val factor = 1600.0 / maxSide.toDouble()
                    android.graphics.Bitmap.createScaledBitmap(
                        bitmap,
                        (bitmap.width * factor).toInt().coerceAtLeast(1),
                        (bitmap.height * factor).toInt().coerceAtLeast(1),
                        true
                    )
                } else bitmap
                ByteArrayOutputStream().use { outBytes ->
                    check(scaled.compress(android.graphics.Bitmap.CompressFormat.JPEG, 84, outBytes)) { "Falha ao preparar a imagem." }
                    if (scaled !== bitmap) scaled.recycle()
                    bitmap.recycle()
                    outBytes.toByteArray()
                }
            } ?: error("Não consegui abrir a imagem selecionada.")

            if (settings.openRouterKey.isNotBlank()) {
                OpenRouterOrchestrator.describeScreen(
                    this@MainActivity, settings,
                    "Analise esta imagem enviada pelo usuário. Descreva o que está visível e responda de forma útil ao contexto atual.",
                    jpeg, "Imagem escolhida pelo usuário; não é uma captura de tela."
                )
            } else {
                AgentOrchestrator.describeScreen(
                    settings.xkiroKey,
                    "Analise esta imagem enviada pelo usuário e descreva o que está visível.",
                    jpeg, "Imagem escolhida pelo usuário."
                )
            }
        }
    }

    private val exportWork = registerForActivityResult(ActivityResultContracts.CreateDocument("application/zip")) { uri ->
        if (uri == null) return@registerForActivityResult
        val ok = runCatching { WorkEngine.exportLatest(this, uri) }.getOrDefault(false)
        toast(if (ok) "Workspace exportado." else "Não encontrei um Work para exportar.")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        store = SettingsStore(this)
        bind()
        loadSettings()
        wireActions()
        updateShizukuStatus()
        updateAccessibilityStatus()
        updateWorkStatus()
        animateEntrance()
        scope.launch { delay(550); autoDoctor(false) }
        screenHealthTask=scope.launch { while(isActive){ updateScreenVisionButton(); delay(1000) } }
    }

    override fun onResume() {
        super.onResume()
        updateShizukuStatus()
        updateAccessibilityStatus()
        updateWorkStatus()
        scope.launch {
            delay(350)
            updateAccessibilityStatus()
            autoDoctor(false)
        }
    }

    private fun wireActions() {
        findViewById<Button>(R.id.saveSettings).setOnClickListener { saveSettings() }
        findViewById<Button>(R.id.refreshModels).setOnClickListener { refreshModels() }
        findViewById<Button>(R.id.researchWeb).setOnClickListener {
            val text = prompt.text.toString().trim()
            if (text.isBlank()) toast("Escreva o que devo pesquisar.") else runResearch(text)
        }
        findViewById<Button>(R.id.runDoctor).setOnClickListener { runDoctor() }
        findViewById<Button>(R.id.swarmDemo).setOnClickListener {
            runNormalPrompt("Faça uma revisão rápida da arquitetura deste AI Studio e proponha 3 melhorias práticas.")
        }
        findViewById<Button>(R.id.runWork).setOnClickListener {
            val text = prompt.text.toString().trim()
            if (text.isBlank()) toast("Escreva o que o Work deve criar.") else runWork(text)
        }
        findViewById<Button>(R.id.exportWork).setOnClickListener {
            if (WorkEngine.latestWorkspace(this) == null) toast("Nenhum workspace Work ainda.")
            else exportWork.launch("Diana-Work-${System.currentTimeMillis()}.zip")
        }
        findViewById<Button>(R.id.sendPrompt).setOnClickListener { runTypedPrompt(prompt.text.toString()) }

        findViewById<Button>(R.id.openAccessibility).setOnClickListener {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }
        findViewById<Button>(R.id.allowShizuku).setOnClickListener { requestShizukuPermission() }
        findViewById<Button>(R.id.prepareTermux).setOnClickListener { prepareTermux() }
        findViewById<Button>(R.id.startVoice).setOnClickListener {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) startVoiceService()
            else micPermission.launch(Manifest.permission.RECORD_AUDIO)
        }
        findViewById<Button>(R.id.stopVoice).setOnClickListener { stopVoiceMode() }
        findViewById<Button>(R.id.testVoice).setOnClickListener { testElevenLabs() }
        findViewById<Button>(R.id.shareScreen).setOnClickListener { startFullScreenVision() }
        findViewById<Button>(R.id.testScreenVision).setOnClickListener { testScreenVision() }
        findViewById<Button>(R.id.analyzeImage).setOnClickListener { pickImage.launch(arrayOf("image/*")) }
        findViewById<Button>(R.id.stopScreen).setOnClickListener { stopScreenSharing() }
        findViewById<Button>(R.id.stopTask).setOnClickListener { interruptCurrentTask(false) }
        findViewById<Button>(R.id.stopEverything).setOnClickListener { interruptCurrentTask(true) }
        findViewById<Button>(R.id.settingsButton).setOnClickListener {
            val panel = findViewById<View>(R.id.settingsPanel)
            panel.visibility = if (panel.visibility == View.VISIBLE) View.GONE else View.VISIBLE
        }
        findViewById<Button>(R.id.historyButton).setOnClickListener { toast("Histórico será conectado na próxima etapa.") }
        findViewById<Button>(R.id.viewExecution).setOnClickListener {
            if (ScreenCaptureService.isStreaming()) testScreenVision() else startFullScreenVision()
        }
        findViewById<Button>(R.id.modeChat).setOnClickListener { toast("Modo Chat") }
        findViewById<Button>(R.id.modeWork).setOnClickListener { toast("Modo Work") }
        findViewById<Button>(R.id.modeDevice).setOnClickListener {
            if (!ScreenCaptureService.isStreaming()) startFullScreenVision() else toast("Aparelho pronto para controle visual.")
        }
    }

    private fun bind() {
        out = findViewById(R.id.output)
        modelsText = findViewById(R.id.modelsText)
        workStatus = findViewById(R.id.workStatus)
        shizukuStatus = findViewById(R.id.shizukuStatus)
        accessibilityStatus = findViewById(R.id.accessibilityStatus)
        doctorStatus = findViewById(R.id.doctorStatus)
        runtimeStatus = findViewById(R.id.runtimeStatus)
        assistantCard = findViewById(R.id.assistantCard)
        openRouterKey = findViewById(R.id.openRouterKey)
        dailyBudget = findViewById(R.id.dailyBudget)
        taskBudget = findViewById(R.id.taskBudget)
        xKey = findViewById(R.id.xkiroKey)
        vKey = findViewById(R.id.voiceKey)
        vId = findViewById(R.id.voiceId)
        wake = findViewById(R.id.wakeWord)
        prompt = findViewById(R.id.prompt)
    }

    private fun loadSettings() {
        val s = store.load()
        openRouterKey.setText(s.openRouterKey)
        dailyBudget.setText("%.2f".format(Locale.US, s.openRouterDailyBudgetUsd))
        taskBudget.setText("%.2f".format(Locale.US, s.openRouterTaskBudgetUsd))
        xKey.setText(s.xkiroKey)
        vKey.setText(s.voiceKey)
        vId.setText(s.voiceId)
        wake.setText(if (s.wakeWord == "Orizon") "Diana" else s.wakeWord)
    }

    private fun currentSettings(): StudioSettings {
        fun money(e: EditText, fallback: Double) = e.text.toString().trim().replace(',', '.').toDoubleOrNull() ?: fallback
        val task = money(taskBudget, 0.25).coerceIn(0.01, 10.0)
        val daily = money(dailyBudget, 1.0).coerceAtLeast(task).coerceAtMost(50.0)
        return StudioSettings(
            openRouterKey = openRouterKey.text.toString().trim(),
            openRouterDailyBudgetUsd = daily,
            openRouterTaskBudgetUsd = task,
            xkiroKey = xKey.text.toString().trim(),
            voiceKey = vKey.text.toString().trim(),
            voiceId = vId.text.toString().trim(),
            wakeWord = wake.text.toString().trim().ifBlank { "Diana" }
        )
    }

    private fun saveSettings() {
        val s = currentSettings()
        store.save(s)
        dailyBudget.setText("%.2f".format(Locale.US, s.openRouterDailyBudgetUsd))
        taskBudget.setText("%.2f".format(Locale.US, s.openRouterTaskBudgetUsd))
        toast("Configurações salvas localmente.")
        updateShizukuStatus()
    }

    private fun startFullScreenVision() {
        val mgr = getSystemService(MediaProjectionManager::class.java)
        val intent = if (Build.VERSION.SDK_INT >= 34) {
            mgr.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
        } else mgr.createScreenCaptureIntent()
        runtimeStatus.text = "Autorize a captura da tela inteira no Android"
        capturePermission.launch(intent)
    }

    private fun testScreenVision() {
        val s = currentSettings()
        if (s.openRouterKey.isBlank() && s.xkiroKey.isBlank()) return toast("Configure OpenRouter ou xKiro primeiro.")
        beginTask("Testando visão da tela") {
            val health = ScreenCaptureService.healthText()
            if (!ScreenCaptureService.active) return@beginTask "Screen Vision não está ativo. Toque em 'Compartilhar tela inteira'."
            DeviceAgentController.execute(this@MainActivity, s, "veja minha tela e descreva objetivamente o que está visível agora") { status ->
                runOnUiThread { runtimeStatus.text = status.take(80) }
            }.message + "\n\nCaptura: $health"
        }
    }

    private fun prepareTermux() {
        if (!TermuxBridge.installed(this)) return toast("Termux não está instalado.")
        if (!TermuxBridge.hasPermission(this)) {
            termuxPermission.launch(TermuxBridge.PERMISSION)
            return
        }
        val setup = "mkdir -p ~/.termux && grep -q '^allow-external-apps *= *true' ~/.termux/termux.properties 2>/dev/null || printf '\\nallow-external-apps = true\\n' >> ~/.termux/termux.properties; termux-reload-settings"
        packageManager.getLaunchIntentForPackage("com.termux")?.let { startActivity(it) }
        getSystemService(android.content.ClipboardManager::class.java).setPrimaryClip(
            android.content.ClipData.newPlainText("Diana Termux setup", setup)
        )

        scope.launch {
            delay(650)
            ShizukuBridge.connectUserService()
            val paste = if (ShizukuBridge.hasPermission()) ShizukuBridge.keyEvent(279) else Result.failure(IllegalStateException("Shizuku indisponível"))
            val enter = if (paste.isSuccess) ShizukuBridge.keyEvent(66) else Result.failure(IllegalStateException("Paste não executado"))
            if (paste.isSuccess && enter.isSuccess) {
                runtimeStatus.text = "Termux: configuração enviada; aguardando aplicação"
                out.text = "Enviei a preparação diretamente ao Termux. Aguarde o prompt voltar e depois tente o comando novamente."
            } else {
                runtimeStatus.text = "Termux: precisa de uma preparação manual"
                out.text = "Abri o Termux e deixei o comando de preparação na área de transferência. Cole uma vez no Termux e pressione Enter. Depois disso a Diana poderá usar a integração oficial RUN_COMMAND sem depender de colar comandos grandes."
            }
        }
    }

    private fun requestShizukuPermission() {
        if (ShizukuBridge.hasPermission()) {
            updateShizukuStatus()
            return toast("Shizuku já está autorizado.")
        }
        if (ShizukuBridge.binderAlive) {
            ShizukuBridge.requestPermission()
            shizukuStatus.text = "aguardando"
            scope.launch { delay(900); updateShizukuStatus() }
            return
        }
        packageManager.getLaunchIntentForPackage("moe.shizuku.privileged.api")?.let {
            startActivity(it); toast("Ative o Shizuku e volte para autorizar a Diana.")
        } ?: toast("Shizuku não está conectado. Abra o app Shizuku primeiro.")
        updateShizukuStatus()
    }

    private fun updateShizukuStatus() {
        if (ShizukuBridge.hasPermission()) ShizukuBridge.connectUserService()
        shizukuStatus.text = when {
            ShizukuBridge.hasPermission() -> "conectado"
            ShizukuBridge.binderAlive -> "autorizar"
            else -> "desligado"
        }
        shizukuStatus.setTextColor(ContextCompat.getColor(this, if (ShizukuBridge.hasPermission()) R.color.success else R.color.muted))
    }

    private fun updateAccessibilityStatus() {
        val enabled = StudioAccessibilityService.isEnabled(this)
        val connected = StudioAccessibilityService.instance != null
        accessibilityStatus.text = when {
            connected -> "conectado"
            enabled -> "reconectando"
            else -> "desligado"
        }
        accessibilityStatus.setTextColor(ContextCompat.getColor(this, if (connected) R.color.success else R.color.muted))
        findViewById<Button>(R.id.openAccessibility).text = "›"
    }

    private suspend fun autoDoctor(deep: Boolean) {
        val report = DoctorEngine.diagnoseAndRecover(this, currentSettings(), deep)
        doctorStatus.text = if (report.healthy)
            "Doctor: monitorando • sistemas principais recuperáveis"
        else "Doctor: ${report.summary.take(120)}"
    }

    private fun runDoctor() {
        beginUtility("Doctor verificando os sistemas") {
            val report = DoctorEngine.diagnoseAndRecover(this@MainActivity, currentSettings(), true)
            doctorStatus.text = if (report.healthy) "Doctor: tudo saudável" else "Doctor: ${report.summary.take(120)}"
            report.details
        }
    }

    private fun updateWorkStatus() {
        workStatus.text = WorkEngine.latestWorkspace(this)?.let { "Work: ${it.name} • ${it.fileCount} arquivo(s)" }
            ?: "Work: nenhum workspace criado ainda."
    }

    private fun refreshModels() {
        val s = currentSettings()
        if (s.openRouterKey.isBlank() && s.xkiroKey.isBlank()) return toast("Configure OpenRouter ou xKiro.")
        beginUtility("Atualizando roteamento e modelos") {
            val blocks = mutableListOf<String>()
            if (s.openRouterKey.isNotBlank()) {
                val info = OpenRouterOrchestrator.modelSummary(this@MainActivity, s)
                blocks += info
            }
            if (s.xkiroKey.isNotBlank()) {
                blocks += runCatching {
                    val r = AgentOrchestrator.probeModels(s.xkiroKey)
                    val names = r.verifiedUsable.take(12).joinToString("\n") { "• ${it.id}" }
                    "xKiro: ${r.totalCatalog} no catálogo • ${r.verifiedUsable.size} utilizáveis • ${r.blockedInProbe} recusados\n$names"
                }.getOrElse { "xKiro: ${it.message}" }
            }
            modelsText.text = blocks.joinToString("\n\n")
            modelsText.text.toString()
        }
    }

    private fun beginUtility(label: String, block: suspend () -> String) {
        utilityTask?.cancel()
        runtimeStatus.text = label
        utilityTask = scope.launch {
            runCatching { block() }
                .onSuccess {
                    if (activeTask == null || activeTask?.isActive != true) runtimeStatus.text = "Pronto"
                    if (it.isNotBlank()) out.text = it
                    animateOutput()
                }
                .onFailure {
                    if (it is CancellationException) runtimeStatus.text = "Interrompido"
                    else {
                        runtimeStatus.text = "Doctor verificando a falha…"
                        val report = runCatching { DoctorEngine.diagnoseAndRecover(this@MainActivity, currentSettings(), true) }.getOrNull()
                        if (report != null) {
                            doctorStatus.text = "Doctor: ${report.summary.take(120)}"
                            out.text = "${it.message ?: it.javaClass.simpleName}\n\nDoctor: ${report.details}"
                            runtimeStatus.text = "Falha diagnosticada"
                        } else runtimeStatus.text = "Falha"
                    }
                }
        }
    }

    private fun runTypedPrompt(text: String) {
        if (text.isBlank()) return toast("Digite uma tarefa.")
        val s = currentSettings()
        if (s.openRouterKey.isBlank() && s.xkiroKey.isBlank()) return toast("Configure sua OpenRouter API key ou xKiro.")
        prompt.clearFocus()
        out.text = "Entendi. Vou trabalhar nisso…"
        when {
            DeviceAgentController.looksLikeDeviceCommand(text) -> runDevicePrompt(text,s)
            WorkEngine.looksLikeWorkCommand(text) -> runWork(text)
            looksLikeResearchRequest(text) -> runResearch(text)
            else -> runNormalPrompt(text)
        }
    }

    private fun runDevicePrompt(text:String,s:StudioSettings=currentSettings()){
        if(!ScreenCaptureService.isStreaming()){ pendingDeviceCommand=text; out.text="Vou usar o Screen Vision. Autorize o compartilhamento da tela e eu continuo automaticamente."; runtimeStatus.text="Screen Vision precisa de autorização"; startFullScreenVision(); return }
        activeTask?.cancel(); DeviceAgentController.resetCancellation(); runtimeStatus.text="Device Agent • visão + ações"; findViewById<Button>(R.id.stopScreen).isEnabled=false
        activeTask=scope.launch {
            runCatching { DeviceAgentController.execute(this@MainActivity,s,text){ st-> runOnUiThread { out.text=st; runtimeStatus.text=st.substringBefore('…').take(70) } } }
                .onSuccess { result->
                    findViewById<Button>(R.id.stopScreen).isEnabled=true
                    if(result.requiresScreenVisionReauth || result.message.startsWith(DeviceAgentController.VISION_REAUTH_PREFIX)){ pendingDeviceCommand=text; out.text=result.message.removePrefix(DeviceAgentController.VISION_REAUTH_PREFIX).trim()+"\n\nVou pedir autorização novamente e continuar."; runtimeStatus.text="Screen Vision caiu • reautorizando"; delay(180); startFullScreenVision() }
                    else { out.text=result.message; runtimeStatus.text="Pronto"; animateOutput(); scope.launch { runCatching { autoDoctor(false) } } }
                }.onFailure { err->
                    findViewById<Button>(R.id.stopScreen).isEnabled=true
                    if(err is CancellationException){ out.text="Tarefa interrompida por você."; runtimeStatus.text="Interrompido" }
                    else { out.text="Device Agent falhou: ${err.message}"; runtimeStatus.text="Falha no Device Agent"; scope.launch { runCatching { autoDoctor(false) } } }
                }
        }
    }

    private fun updateScreenVisionButton(){
        if(!::runtimeStatus.isInitialized) return
        val streaming = ScreenCaptureService.isStreaming()
        findViewById<Button>(R.id.shareScreen).text = "›"
        findViewById<TextView>(R.id.screenVisionStatus).text = when {
            streaming -> "Screen Vision • frame #${ScreenCaptureService.frameCount} • ${ScreenCaptureService.frameAgeMs().coerceAtLeast(0)} ms"
            ScreenCaptureService.active -> "Screen Vision • autorizado • aguardando vídeo"
            else -> "Screen Vision • desligado"
        }
        findViewById<TextView>(R.id.screenVisionRowStatus).apply {
            text = when {
                streaming -> "ao vivo"
                ScreenCaptureService.active -> "aguardando"
                else -> "desligado"
            }
            setTextColor(ContextCompat.getColor(this@MainActivity, if (streaming) R.color.success else R.color.muted))
        }
        val access = StudioAccessibilityService.instance != null
        val shizuku = ShizukuBridge.hasPermission()
        findViewById<TextView>(R.id.deviceCount).text = "${listOf(access, shizuku, streaming).count { it }}/3 ativos"
    }

    private fun looksLikeResearchRequest(text: String): Boolean {
        val t = text.lowercase(Locale.ROOT)
        return listOf(
            "pesquise na internet", "pesquisa na internet", "procure na internet", "buscar na internet",
            "pesquise online", "pesquisa online", "fontes atuais", "notícias de hoje", "noticias de hoje",
            "o que aconteceu hoje", "últimas notícias", "ultimas noticias", "verifique na web"
        ).any { it in t }
    }

    private fun runResearch(text: String) {
        val s = currentSettings()
        if (s.openRouterKey.isBlank()) return toast("Pesquisa web usa a chave do OpenRouter.")
        beginTask("Research Agent • pesquisando a web") {
            OpenRouterBudget.beginTask()
            OpenRouterOrchestrator.webResearch(this@MainActivity, s, text)
        }
    }

    private fun animateEntrance() {
        assistantCard.alpha = 0f
        assistantCard.translationY = 24f
        AnimatorSet().apply {
            playTogether(
                ObjectAnimator.ofFloat(assistantCard, View.ALPHA, 0f, 1f),
                ObjectAnimator.ofFloat(assistantCard, View.TRANSLATION_Y, 24f, 0f)
            )
            duration = 360
            start()
        }
    }

    private fun animateOutput() {
        out.animate().cancel()
        out.alpha = 0.45f
        out.translationY = 8f
        out.animate().alpha(1f).translationY(0f).setDuration(220).start()
    }

    private fun runWork(text: String) {
        val s = currentSettings()
        if (s.openRouterKey.isBlank() && s.xkiroKey.isBlank()) return toast("Configure OpenRouter ou xKiro.")
        beginTask("Work • executando tarefa") {
            WorkEngine.run(
                this@MainActivity,
                s,
                text
            ) { status ->
                runOnUiThread { out.text = status; runtimeStatus.text = status.take(70) }
            }.also { runOnUiThread { updateWorkStatus() } }
        }
    }

    private fun runNormalPrompt(text: String) {
        val s = currentSettings()
        beginTask(if (s.openRouterKey.isNotBlank()) "OpenRouter • modo econômico" else "Diana trabalhando") {
            if (s.openRouterKey.isNotBlank()) {
                OpenRouterBudget.beginTask()
                OpenRouterOrchestrator.chat(this@MainActivity, s, text)
            } else {
                AgentOrchestrator.chat(
                    s.xkiroKey,
                    "Você é a assistente principal Diana. Responda em português do Brasil, seja prático, preciso e econômico em tokens. O roteador escolhe automaticamente um ou vários modelos conforme a dificuldade. Para tarefas de arquivos, recomende usar o modo Work.",
                    text
                )
            }
        }
    }

    private fun beginTask(label: String, block: suspend () -> String) {
        activeTask?.cancel()
        DeviceAgentController.resetCancellation()
        runtimeStatus.text = label
        activeTask = scope.launch {
            runCatching { block() }
                .onSuccess {
                    out.text = it
                    runtimeStatus.text = "Pronto"
                    animateOutput()
                    scope.launch { runCatching { autoDoctor(false) } }
                }
                .onFailure { err ->
                    if (err is CancellationException) {
                        out.text = "Tarefa interrompida por você."
                        runtimeStatus.text = "Interrompido"
                    } else {
                        out.text = "Falha: ${err.message ?: err.javaClass.simpleName}"
                        runtimeStatus.text = "Falha"
                        scope.launch { runCatching { autoDoctor(false) } }
                    }
                }
        }
    }

    private fun testElevenLabs() {
        val s = currentSettings()
        if (s.voiceKey.isBlank() || s.voiceId.isBlank()) return toast("Configure a API key e o Voice ID do ElevenLabs.")
        beginUtility("Testando ElevenLabs com áudio real…") {
            val file = File(cacheDir, "eleven-test.mp3")
            ElevenVoiceClient.synthesize(s.voiceKey, s.voiceId, "Teste concluído. A voz do ElevenLabs está funcionando na Diana.", file)
            withContext(Dispatchers.Main) {
                testVoicePlayer?.release()
                testVoicePlayer = MediaPlayer().apply {
                    setDataSource(file.absolutePath)
                    setOnCompletionListener { it.release(); if (testVoicePlayer === it) testVoicePlayer = null }
                    prepare()
                    start()
                }
                runtimeStatus.text = "ElevenLabs funcionando"
            }
            "Áudio do ElevenLabs reproduzido com sucesso."
        }
    }

    private fun startVoiceService() {
        val s = currentSettings()
        if (s.openRouterKey.isBlank() && s.xkiroKey.isBlank()) return toast("Configure OpenRouter ou xKiro antes da voz.")
        store.save(s)
        ContextCompat.startForegroundService(this, Intent(this, VoiceAssistantService::class.java))
        runtimeStatus.text = "Voz em segundo plano ativa"
    }

    private fun stopVoiceMode() {
        stopService(Intent(this, VoiceAssistantService::class.java))
        runtimeStatus.text = "Voz interrompida"
    }

    private fun stopScreenSharing() {
        stopService(Intent(this, ScreenCaptureService::class.java))
        pendingDeviceCommand = null
        runtimeStatus.text = "Compartilhamento de tela interrompido"
        updateScreenVisionButton()
    }

    private fun interruptCurrentTask(everything: Boolean) {
        DeviceAgentController.cancelCurrent()
        activeTask?.cancel()
        activeTask = null
        utilityTask?.cancel()
        utilityTask = null
        pendingDeviceCommand = null
        if (everything) {
            stopService(Intent(this, VoiceAssistantService::class.java))
            stopService(Intent(this, ScreenCaptureService::class.java))
        }
        runtimeStatus.text = "Interrompido"
        out.text = if (everything) "Tudo foi interrompido." else "Tarefa atual interrompida."
        updateScreenVisionButton()
    }

    override fun onDestroy() {
        screenHealthTask?.cancel()
        scope.cancel()
        testVoicePlayer?.release()
        super.onDestroy()
    }

    private fun toast(s: String) = Toast.makeText(this, s, Toast.LENGTH_SHORT).show()
}
''')

# Diana branding + migration
p=root/'app/src/main/res/values/strings.xml'
s=p.read_text().replace('<string name="app_name">xKiro AI Studio</string>','<string name="app_name">Diana</string>')
p.write_text(s)
p=root/'app/src/main/java/ai/xkiro/studio/core/SettingsStore.kt'
s=p.read_text().replace('prefs.getString("wake_word", "Orizon") ?: "Orizon"','prefs.getString("wake_word", "Diana") ?: "Diana"').replace('.ifBlank { "Orizon" }','.ifBlank { "Diana" }')
p.write_text(s)
p=root/'app/src/main/java/ai/xkiro/studio/device/ScreenCaptureService.kt'
s=p.read_text().replace('xKiro Screen Vision','Diana Screen Vision')
p.write_text(s)
p=root/'app/src/main/java/ai/xkiro/studio/voice/VoiceAssistantService.kt'
s=p.read_text().replace('xKiro Voice Mode','Diana Voice Mode').replace('assistente de voz do xKiro AI Studio','assistente de voz Diana').replace('assistente de voz xKiro','assistente de voz Diana')
p.write_text(s)
# migrate old visible wake word in MainActivity
p=root/'app/src/main/java/ai/xkiro/studio/MainActivity.kt'
s=p.read_text().replace('wake.setText(s.wakeWord)','wake.setText(if (s.wakeWord == "Orizon") "Diana" else s.wakeWord)')
p.write_text(s)
# version
p=root/'app/build.gradle.kts'
s=p.read_text()
if 'versionCode = 20' not in s or 'versionName = "0.2.9"' not in s: raise SystemExit('version marker missing')
s=s.replace('versionCode = 20','versionCode = 21',1).replace('versionName = "0.2.9"','versionName = "0.3.0"',1)
p.write_text(s)
print('Applied Diana v0.3.0 UI')