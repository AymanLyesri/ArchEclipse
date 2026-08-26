hl.env("HYPRCURSOR_SIZE", "24")

-- With the display cable on the RTX 4080, aquamarine must take that card as
-- the PRIMARY device: the first entry is what Hyprland renders on, the rest
-- are kept open so their outputs still work. Listing the iGPU second means a
-- monitor plugged into the motherboard keeps lighting up, and the iGPU stays
-- available as a render device for anything that asks for it.
--
-- By-path, not /dev/dri/cardN: the numbering is discovery order and can swap
-- between boots, which would silently make the wrong card primary.
--
-- (Until the cable actually moves, this makes Hyprland render on the 4080 and
-- scan out through the iGPU — the reverse of what is wanted, and the exact
-- cross-GPU path whose fence loss has been crashing the session. Comment
-- these three lines out to go back.)
hl.env("AQ_DRM_DEVICES", "/dev/dri/by-path/pci-0000:01:00.0-card:/dev/dri/by-path/pci-0000:11:00.0-card")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
