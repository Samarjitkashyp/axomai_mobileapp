@echo off
echo ==============================================
echo   Building Axom AI Mobile APK (Release)
echo ==============================================
set PUB_CACHE=E:\pub_cache
flutter build apk --release
echo.
echo ==============================================
echo   APK Build Finished!
echo   Location: build\app\outputs\flutter-apk\app-release.apk
echo ==============================================
pause
