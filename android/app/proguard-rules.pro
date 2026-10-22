# Reglas de R8 para el build de release.
#
# shared_preferences_android y path_provider_android (versiones recientes) se
# llaman desde Dart por JNI (paquete `jni`/jnigen): R8 no ve esas llamadas y
# borraba sus metodos, y la app se quedaba en negro al abrir con
# NoSuchMethodError en SharedPreferencesApiRegistrar.getAll (antes de runApp).
-keep class io.flutter.plugins.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
# La libreria jni busca por nombre clases de Kotlin (Continuation, Result,
# CoroutineSingletons...) al llamar funciones suspend: R8 no debe tocarlas.
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-keepattributes Signature, *Annotation*
