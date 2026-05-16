--!strict
export type Snapshot = {
	timestamp: number,
	position: Vector3,
}

export type HitboxConfig = {
	bufferSize: number, -- number of snapshots
	snapshotInterval: number, -- in seconds
}

export type HitboxData = {
	buffer: buffer,
	config: HitboxConfig,
	lastIndex: number,
}

return {}
