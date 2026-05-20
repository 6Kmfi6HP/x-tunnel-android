package com.xtunnel.android.model

import java.net.URI

data class XTunnelProfile(
    val name: String,
    val serverUrl: String,
    val token: String,
    val socksListen: String = "socks5://127.0.0.1:11080",
    val connections: Int = 1,
    val insecure: Boolean = false,
)

object DefaultProfile {
    val local = XTunnelProfile(
        name = "Local test",
        serverUrl = "ws://127.0.0.1:18080/tunnel",
        token = "local-test-token",
    )
}

fun XTunnelProfile.validationError(): String? {
    if (name.isBlank()) return "Profile name is required"
    if (token.isBlank()) return "Token is required"
    if (connections !in 1..16) return "Connections must be between 1 and 16"

    val server = runCatching { URI(serverUrl) }.getOrNull()
        ?: return "Server URL is invalid"
    if (server.scheme !in setOf("ws", "wss")) {
        return "Server URL must start with ws:// or wss://"
    }
    if (server.host.isNullOrBlank()) return "Server URL host is required"

    val socks = runCatching { URI(socksListen) }.getOrNull()
        ?: return "SOCKS listen URL is invalid"
    if (socks.scheme != "socks5") return "SOCKS listen must start with socks5://"
    if (socks.host.isNullOrBlank()) return "SOCKS listen host is required"
    if (socks.port !in 1..65535) return "SOCKS listen port is invalid"

    return null
}
