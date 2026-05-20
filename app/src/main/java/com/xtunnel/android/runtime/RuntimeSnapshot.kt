package com.xtunnel.android.runtime

data class RuntimeSnapshot(
    val state: RuntimeState = RuntimeState.Stopped,
    val profileName: String = "",
    val detail: String = "Stopped",
    val controlUrl: String = "",
    val pid: Int? = null,
    val dataPathState: VpnDataPathState = VpnDataPathState.NotStarted,
    val dataPathDetail: String = "VPN data path not started",
    val updatedAtMillis: Long = System.currentTimeMillis(),
)

enum class RuntimeState {
    Stopped,
    Starting,
    Ready,
    Stopping,
    Failed,
}

enum class VpnDataPathState {
    NotStarted,
    MissingTun2Socks,
    Running,
    Failed,
}

object RuntimeStateStore {
    @Volatile
    private var current = RuntimeSnapshot()

    fun snapshot(): RuntimeSnapshot = current

    fun update(snapshot: RuntimeSnapshot) {
        current = snapshot
    }
}
