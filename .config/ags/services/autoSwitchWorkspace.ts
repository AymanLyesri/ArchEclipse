import hyprland from "gi://AstalHyprland";
import { autoWorkspaceSwitching, focusedWorkspace } from "../variables";

const Hyprland = hyprland.get_default();

const GAMING_WORKSPACE = 10;
let hasSwitchedToGaming = false; // <-- track if we've already switched

Hyprland.connect("notify::clients", () => {
  const clients = Hyprland.clients;

  const hasGamingWindow = clients.some(
    (c) => c.workspace?.id === GAMING_WORKSPACE
  );

  const current = focusedWorkspace()?.id;

  if (
    autoWorkspaceSwitching().value &&
    hasGamingWindow &&
    !hasSwitchedToGaming && // only if we haven't switched before
    current !== GAMING_WORKSPACE
  ) {
    Hyprland.message_async(`dispatch workspace ${GAMING_WORKSPACE}`, () => {});
    hasSwitchedToGaming = true; // mark as switched
  }

  // reset if workspace 10 becomes empty
  if (!hasGamingWindow) {
    hasSwitchedToGaming = false;
  }
});
