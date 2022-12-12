local M = {}

----------------------------------------------------------------------
--                   cmds of lazy loaded plugins                    --
----------------------------------------------------------------------

M.packer_cmds = {
	"PackerSnapshot",
	"PackerSnapshotRollback",
	"PackerSnapshotDelete",
	"PackerInstall",
	"PackerUpdate",
	"PackerSync",
	"PackerClean",
	"PackerCompile",
	"PackerStatus",
	"PackerProfile",
	"PackerLoad",
}

M.treesitter_cmds = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSEnable", "TSDisable", "TSModuleInfo" }

return M
