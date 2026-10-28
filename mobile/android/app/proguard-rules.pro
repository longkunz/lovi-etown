# R8 keep rules for OkHttp's optional TLS providers.
# OkHttp probes BouncyCastle, Conscrypt and OpenJSSE reflectively at runtime;
# none of them is bundled with the app, so R8 must not fail on the missing
# classes. These rules are exactly the set R8 generated in
# build/app/outputs/mapping/release/missing_rules.txt during the 1.0.3 build.
-dontwarn org.bouncycastle.jsse.BCSSLParameters
-dontwarn org.bouncycastle.jsse.BCSSLSocket
-dontwarn org.bouncycastle.jsse.provider.BouncyCastleJsseProvider
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE
