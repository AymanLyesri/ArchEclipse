import Gtk from "gi://Gtk?version=4.0";
import { focusedWorkspace } from "../../../variables";

import Hyprland from "gi://AstalHyprland";
import { createBinding, createComputed } from "ags";
import { hideWindow, showWindow } from "../../../utils/window";
import { For } from "ags";
import { Accessor } from "ags";

const hyprland = Hyprland.get_default();

// workspaces icons
const workspaceToIcon = ["", "", "", "", "", "", "󰙯", "󰓓", "", "", ""];
function Workspaces() {
  /**
   * WORKSPACE STATE TRACKING
   *
   * We need to persist state across re-renders to detect transitions.
   * This stores the complete state of each workspace from the previous render.
   *
   * Map structure: { workspaceId: { isActive, isFocused } }
   */
  let previousWorkspaceStates = new Map<
    number,
    { isActive: boolean; isFocused: boolean }
  >();

  // Icons configuration
  const emptyIcon = ""; // Icon for empty workspaces
  const extraWorkspaceIcon = ""; // Icon for workspaces beyond maxWorkspaces
  const maxWorkspaces = 10; // Maximum number of workspaces with custom icons

  /**
   * WORKSPACE BUTTON CREATOR
   *
   * Creates a button with classes that represent both current state and transitions.
   * Classes are mutually exclusive to prevent conflicts:
   *
   * FOCUS STATES (mutually exclusive):
   * - "is-focused": Currently focused workspace
   * - "is-unfocused": Not currently focused
   *
   * ACTIVE STATES (mutually exclusive):
   * - "is-active": Has windows
   * - "is-inactive": No windows
   *
   * TRANSITION STATES (can combine with above):
   * - "trans-gaining-focus": Transitioning from unfocused to focused
   * - "trans-losing-focus": Transitioning from focused to unfocused
   * - "trans-becoming-active": Transitioning from inactive to active
   * - "trans-becoming-inactive": Transitioning from active to inactive
   */
  const createWorkspaceButton = (
    id: number,
    isActive: boolean,
    isFocused: boolean,
    icon: string
  ) => {
    const classes: string[] = [];

    // Get previous state for this workspace (if it existed)
    const prevState = previousWorkspaceStates.get(id);

    // ===== CURRENT STATE CLASSES =====
    // These represent the current state only
    classes.push(isFocused ? "is-focused" : "is-unfocused");
    classes.push(isActive ? "is-active" : "is-inactive");

    // ===== TRANSITION CLASSES =====
    // Only add transition classes if we have previous state to compare
    if (prevState) {
      // Focus transitions
      if (!prevState.isFocused && isFocused) {
        classes.push("trans-gaining-focus");
      } else if (prevState.isFocused && !isFocused) {
        classes.push("trans-losing-focus");
      }

      // Active transitions
      if (!prevState.isActive && isActive) {
        classes.push("trans-becoming-active");
      } else if (prevState.isActive && !isActive) {
        classes.push("trans-becoming-inactive");
      }
    }

    return (
      <button
        class={classes.join(" ")}
        label={icon}
        onClicked={() =>
          hyprland.message_async(`dispatch workspace ${id}`, () => {})
        }
        tooltipText={`SUPER + ${id}`}
      />
    );
  };

  // Reactive workspace state that updates when workspaces or focus changes
  const workspaces: Accessor<any[]> = createComputed(() => {
    const workspaces = createBinding(hyprland, "workspaces")();
    const currentWorkspace = focusedWorkspace().id;

    // Get array of active workspace IDs
    const workspaceIds = workspaces.map((w) => w.id);
    // Calculate total workspaces needed (active ones or maxWorkspaces, whichever is larger)
    const totalWorkspaces = Math.max(...workspaceIds, maxWorkspaces);
    // Create array of all workspace IDs [1, 2, ..., totalWorkspaces]
    const allWorkspaces = Array.from(
      { length: totalWorkspaces },
      (_, i) => i + 1
    );

    // Array to hold the final grouped workspace elements
    let groupElements: any[] = [];
    // Current group of adjacent active workspaces being built
    let currentGroup: any[] = [];
    // Flag indicating if current group contains active workspaces
    let currentGroupIsActive = false;

    /**
     * Finalizes the current workspace group by adding it to groupElements
     * with proper classes and resetting group state
     */
    const finalizeCurrentGroup = () => {
      if (currentGroup.length > 0) {
        groupElements.push(
          <box
            class={`workspace-group ${
              currentGroupIsActive ? "active" : "inactive"
            }`}
          >
            {currentGroup}
          </box>
        );
        // Reset group state
        currentGroup = [];
        currentGroupIsActive = false;
      }
    };

    /**
     * WORKSPACE PROCESSING LOOP
     *
     * Process each workspace and group them:
     * - Active workspaces (with windows) are grouped together
     * - Inactive workspaces (empty) are shown individually
     *
     * This creates visual separation between empty and occupied workspaces.
     */
    allWorkspaces.forEach((id) => {
      const isActive = workspaceIds.includes(id);
      const isFocused = currentWorkspace === id;

      // Select appropriate icon
      const icon =
        id > maxWorkspaces
          ? extraWorkspaceIcon
          : isActive
          ? workspaceToIcon[id]
          : emptyIcon;

      if (isActive) {
        // ACTIVE WORKSPACE: Add to current group
        currentGroupIsActive = true;
        currentGroup.push(createWorkspaceButton(id, isActive, isFocused, icon));

        // Close group if this is the last workspace or next one is inactive
        if (id === allWorkspaces.length || !workspaceIds.includes(id + 1)) {
          finalizeCurrentGroup();
        }
      } else {
        // INACTIVE WORKSPACE: Close any active group and add as standalone
        finalizeCurrentGroup();
        groupElements.push(
          <box class="workspace-group inactive">
            {createWorkspaceButton(id, isActive, isFocused, icon)}
          </box>
        );
      }
    });

    /**
     * STATE PERSISTENCE FOR NEXT RENDER
     *
     * Store current workspace states so we can detect transitions
     * in the next render cycle. This is crucial for animations.
     */
    const newStates = new Map<
      number,
      { isActive: boolean; isFocused: boolean }
    >();

    allWorkspaces.forEach((id) => {
      newStates.set(id, {
        isActive: workspaceIds.includes(id),
        isFocused: currentWorkspace === id,
      });
    });

    previousWorkspaceStates = newStates;

    return groupElements;
  });

  // Render the workspaces container with bound workspace elements
  return (
    <box class="workspaces">
      <For each={workspaces}>
        {(workspace, index: Accessor<number>) => workspace}
      </For>
    </box>
  );
}

const Special = () => (
  <button
    class="special"
    label={workspaceToIcon[0]}
    onClicked={() =>
      hyprland.message_async(`dispatch togglespecialworkspace`, (res) => {})
    }
    tooltipText={"SUPER + S"}
  />
);

const OverView = () => (
  <button
    class="overview"
    label="󱗼"
    onClicked={() =>
      hyprland.message_async("dispatch hyprexpo:expo toggle", (res) => {})
    }
    tooltipText={"SUPER + SHIFT + TAB"}
  />
);

function AppLauncher({ monitorName }: { monitorName: string }) {
  return (
    <togglebutton
      class="app-search"
      label=""
      onToggled={({ active }) => {
        active
          ? showWindow(`app-launcher-${monitorName}`)
          : hideWindow(`app-launcher-${monitorName}`);
      }}
      tooltipText={"SUPER"}
    />
  );
}

// wallpaper switcher

function WallpaperSwitcher({ monitorName }: { monitorName: string }) {
  return (
    <togglebutton
      class="wallpaper-switcher-trigger"
      label="󰸉"
      onToggled={({ active }) => {
        active
          ? showWindow(`wallpaper-switcher-${monitorName}`)
          : hideWindow(`wallpaper-switcher-${monitorName}`);
      }}
      tooltipText={"SUPER + W"}
    />
  );
}

function Settings({ monitorName }: { monitorName: string }) {
  return (
    <togglebutton
      class="settings"
      label=""
      onToggled={({ active }) =>
        active
          ? showWindow(`settings-${monitorName}`)
          : hideWindow(`settings-${monitorName}`)
      }
      tooltipText={"SUPER + ALT + S"}
    />
  );
}

function UserPanel({ monitorName }: { monitorName: string }) {
  return (
    <togglebutton
      class="user-panel"
      label=""
      onToggled={({ active }) => {
        active
          ? showWindow(`user-panel-${monitorName}`)
          : hideWindow(`user-panel-${monitorName}`);
      }}
      tooltipText={"SUPER + ESC"}
    />
  );
}

const Actions = ({ monitorName }: { monitorName: string }) => {
  return (
    <box class="actions">
      <UserPanel monitorName={monitorName} />
      {/* <Settings monitorName={monitorName} /> */}
      <WallpaperSwitcher monitorName={monitorName} />
    </box>
  );
};

export default ({
  monitorName,
  halign,
}: {
  monitorName: string;
  halign: Gtk.Align;
}) => {
  return (
    <box class="bar-left" spacing={5} halign={halign} hexpand>
      <Actions monitorName={monitorName} />
      <OverView />
      <Special />
      <Workspaces />
    </box>
  );
};
