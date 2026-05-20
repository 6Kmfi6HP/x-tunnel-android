package com.xtunnel.android.model

import android.content.Context

object ProfileStore {
    private const val PREFS = "xtunnel_profile"
    private const val KEY_NAME = "name"
    private const val KEY_SERVER_URL = "server_url"
    private const val KEY_TOKEN = "token"
    private const val KEY_SOCKS_LISTEN = "socks_listen"
    private const val KEY_METRICS_LISTEN = "metrics_listen"
    private const val KEY_CIDR = "cidr"
    private const val KEY_DNS = "dns"
    private const val KEY_ECH = "ech"
    private const val KEY_BLOCK_PORTS = "block_ports"
    private const val KEY_CONNECTIONS = "connections"
    private const val KEY_INSECURE = "insecure"
    private const val KEY_FALLBACK = "fallback"

    fun load(context: Context): XTunnelProfile {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return XTunnelProfile(
            name = prefs.getString(KEY_NAME, null) ?: DefaultProfile.local.name,
            serverUrl = prefs.getString(KEY_SERVER_URL, null) ?: DefaultProfile.local.serverUrl,
            token = prefs.getString(KEY_TOKEN, null) ?: DefaultProfile.local.token,
            socksListen = prefs.getString(KEY_SOCKS_LISTEN, null) ?: DefaultProfile.local.socksListen,
            metricsListen = prefs.getString(KEY_METRICS_LISTEN, null) ?: DefaultProfile.local.metricsListen,
            cidr = prefs.getString(KEY_CIDR, null) ?: DefaultProfile.local.cidr,
            dns = prefs.getString(KEY_DNS, null) ?: DefaultProfile.local.dns,
            ech = prefs.getString(KEY_ECH, null) ?: DefaultProfile.local.ech,
            blockPorts = prefs.getString(KEY_BLOCK_PORTS, null) ?: DefaultProfile.local.blockPorts,
            connections = prefs.getInt(KEY_CONNECTIONS, DefaultProfile.local.connections),
            insecure = prefs.getBoolean(KEY_INSECURE, DefaultProfile.local.insecure),
            fallback = prefs.getBoolean(KEY_FALLBACK, DefaultProfile.local.fallback),
        )
    }

    fun save(context: Context, profile: XTunnelProfile) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_NAME, profile.name)
            .putString(KEY_SERVER_URL, profile.serverUrl)
            .putString(KEY_TOKEN, profile.token)
            .putString(KEY_SOCKS_LISTEN, profile.socksListen)
            .putString(KEY_METRICS_LISTEN, profile.metricsListen)
            .putString(KEY_CIDR, profile.cidr)
            .putString(KEY_DNS, profile.dns)
            .putString(KEY_ECH, profile.ech)
            .putString(KEY_BLOCK_PORTS, profile.blockPorts)
            .putInt(KEY_CONNECTIONS, profile.connections)
            .putBoolean(KEY_INSECURE, profile.insecure)
            .putBoolean(KEY_FALLBACK, profile.fallback)
            .apply()
    }
}
