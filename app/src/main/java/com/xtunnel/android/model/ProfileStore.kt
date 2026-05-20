package com.xtunnel.android.model

import android.content.Context

object ProfileStore {
    private const val PREFS = "xtunnel_profile"
    private const val KEY_NAME = "name"
    private const val KEY_SERVER_URL = "server_url"
    private const val KEY_TOKEN = "token"
    private const val KEY_SOCKS_LISTEN = "socks_listen"
    private const val KEY_CONNECTIONS = "connections"
    private const val KEY_INSECURE = "insecure"

    fun load(context: Context): XTunnelProfile {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return XTunnelProfile(
            name = prefs.getString(KEY_NAME, null) ?: DefaultProfile.local.name,
            serverUrl = prefs.getString(KEY_SERVER_URL, null) ?: DefaultProfile.local.serverUrl,
            token = prefs.getString(KEY_TOKEN, null) ?: DefaultProfile.local.token,
            socksListen = prefs.getString(KEY_SOCKS_LISTEN, null) ?: DefaultProfile.local.socksListen,
            connections = prefs.getInt(KEY_CONNECTIONS, DefaultProfile.local.connections),
            insecure = prefs.getBoolean(KEY_INSECURE, DefaultProfile.local.insecure),
        )
    }

    fun save(context: Context, profile: XTunnelProfile) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_NAME, profile.name)
            .putString(KEY_SERVER_URL, profile.serverUrl)
            .putString(KEY_TOKEN, profile.token)
            .putString(KEY_SOCKS_LISTEN, profile.socksListen)
            .putInt(KEY_CONNECTIONS, profile.connections)
            .putBoolean(KEY_INSECURE, profile.insecure)
            .apply()
    }
}
