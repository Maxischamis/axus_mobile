# 1. Eliminar archivos duplicados generados por sincronización
find . -name "* 2.*" -delete
find . -name "* 3.*" -delete
find . -name "* 4.*" -delete
find . -name "*-2.*" -delete

# 2. Limpiar atributos de macOS (Arregla el error 255 de Xcode)
xattr -cr .

# 3. Limpieza profunda de Flutter
/Users/maxi/Documents/Necesarios/flutter/bin/flutter clean
/Users/maxi/Documents/Necesarios/flutter/bin/flutter pub get

# 4. Arreglar configuración de Android (Cambiar NDK a uno estable)
# Abre android/app/build.gradle.kts y cambia ndkVersion a:
# ndkVersion = "26.3.11579264"