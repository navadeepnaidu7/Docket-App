# ── NFC passport stack ───────────────────────────────────────────────────────
# JMRTD/scuba/BouncyCastle resolve providers and LDS file handlers reflectively,
# so they are kept whole rather than relying on R8 to trace the graph.
#
# NOTE: this retains org.bouncycastle.pqc (~1.2 MB), which BAC never uses.
# Narrowing the keep to exclude `pqc` would reclaim it, at the cost of the
# blanket-keep guarantee for the crypto stack.
-keep class org.jmrtd.** { *; }
-keep class net.sf.scuba.** { *; }
-keep class org.bouncycastle.** { *; }
-keep class com.gemalto.jp2.** { *; }
-dontwarn org.bouncycastle.**
-dontwarn org.jmrtd.**
-dontwarn net.sf.scuba.**
-dontwarn javax.naming.**

# ── Flutter deferred components ──────────────────────────────────────────────
# The embedding references Play Core's split-install API, but this app ships no
# deferred components and does not depend on play-core.
-dontwarn com.google.android.play.core.**

# ── ML Kit ───────────────────────────────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# google_mlkit_text_recognition's Java references the Chinese/Devanagari/Japanese/
# Korean recognizer options, but only the Latin artifact is on the classpath.
# We only ever construct TextRecognizerOptions (Latin), so these are unreachable.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
