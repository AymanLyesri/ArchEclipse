-- Special workspace: keep windows at 95% scale (was the deprecated
-- per-layout `dwindle:special_scale_factor = 0.95`; `master:... = 0.5`
-- is not separately expressible now that it lives in one workspace rule).
hl.workspace_rule({
    workspace = "special:special",
    layout_opts = {
        special_scale_factor = 0.95,
    },
})

-- Was `on_created_empty = "foot"` on the special-workspace rule
-- (deprecated: warns every reload). The replacement is a
-- "workspace.created" event handler that checks `.is_empty`.
hl.on("workspace.created", function(ws)
    if ws and ws.is_empty and (ws.name == "special:special" or ws.addressable_name == "special:special") then
        hl.exec_cmd("foot")
    end
end)
