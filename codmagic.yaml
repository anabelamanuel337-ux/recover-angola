workflows:
  android-workflow:
    name: Android APK
    max_build_duration: 60
    instance_type: mac_mini_m2
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
    scripts:
      - name: Set up Flutter
        script: |
          flutter create . --platforms=android --project-name recuperar_angola
          flutter pub get
      - name: Build APK
        script: |
          flutter build apk --release --no-tree-shake-icons
    artifacts:
      - build/app/outputs/flutter-apk/app-release.apk
