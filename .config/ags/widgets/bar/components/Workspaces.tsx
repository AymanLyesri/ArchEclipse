import Gtk from "gi://Gtk?version=4.0";
import { focusedWorkspace, specialWorkspace } from "../../../variables";

import Hyprland from "gi://AstalHyprland";
import { createBinding, createComputed } from "ags";
import { hideWindow, showWindow } from "../../../utils/window";
import { For } from "ags";
import { Accessor } from "ags";
import app from "ags/gtk4/app";
import { workspaceClientLayout } from "../../../utils/workspace";
import { timeout, Timer } from "ags/time";
import { Gdk } from "ags/gtk4";
import GObject from "ags/gobject";

const hyprland = Hyprland.get_default();

const workspaceIconMap: { [name: string]: string } = {
  special: "",
  overview: "󱗼",
  zen: "󰖟",
  firefox: "󰈹",
  code: "",
  foot: "",
  ranger: "󰉋",
  thunar: "󰉋",
  nautilus: "󰉋",
  vlc: "󰕾",
  "spotify-launcher": "",
  spotify: "",
  spotube: "",
  systemmonitor: "",
  discord: "󰙯",
  vencord: "󰙯",
  legcord: "󰙯",
  vesktop: "󰙯",
  steam: "󰓓",
  lutris: "",
  game: "",
};

// const workspaceRegexIconMap: { [regex: RegExp]: string } = {
//   // all that ends with "cord"
//   "/cord$/": "󰙯",
// };

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
    workspace: Hyprland.Workspace | null,
    index: number,
  ) => {
    // Calculate workspace properties
    const id = index + 1;

    // Track previous state for this specific button
    let prevState = previousWorkspaceStates.get(id);

    return (
      <button
        class={createComputed(() => {
          const isActive = workspace !== null;
          const currentWorkspace = focusedWorkspace().id;
          const isFocused = currentWorkspace === id;

          // If workspace exists, listen to client changes
          if (workspace) {
            createBinding(workspace, "clients")();
          }

          const classes: string[] = [];

          // ===== CURRENT STATE CLASSES =====
          classes.push(isFocused ? "is-focused" : "is-unfocused");
          classes.push(isActive ? "is-active" : "is-inactive");

          // ===== TRANSITION CLASSES =====
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

          // Update previous state for next render
          prevState = { isActive, isFocused };
          previousWorkspaceStates.set(id, { isActive, isFocused });

          return classes.join(" ");
        })}
        label={createComputed(() => {
          const isActive = workspace !== null;
          if (!isActive) return emptyIcon;

          const clients = createBinding(workspace!, "clients")();
          const main_client = clients[0];
          const client_class = main_client?.class.toLowerCase() || "empty";

          return workspaceIconMap[client_class] || extraWorkspaceIcon;
        })}
        onClicked={() =>
          hyprland.message_async(`dispatch workspace ${id}`, () => {})
        }
        $={(self) => {
          // --- POPOVER ---
          const popover = new Gtk.Popover({
            has_arrow: true,
            position: Gtk.PositionType.BOTTOM,
            autohide: false,
          });

          popover.set_child(workspaceClientLayout(workspace));
          popover.set_parent(self);

          // --- HOVER LOGIC ---
          let hideTimeout: Timer;

          // Button hover controller
          const buttonMotion = new Gtk.EventControllerMotion();

          buttonMotion.connect("enter", () => {
            if (hideTimeout) {
              hideTimeout.cancel();
            }
            popover.show();
          });

          buttonMotion.connect("leave", () => {
            // Delay hiding to allow moving to popover
            hideTimeout = timeout(50, () => {
              popover.hide();
              hideTimeout.cancel();
            });
          });

          self.add_controller(buttonMotion);

          // Popover hover controller
          const popoverMotion = new Gtk.EventControllerMotion();

          popoverMotion.connect("enter", () => {
            if (hideTimeout) {
              hideTimeout.cancel();
            }
          });

          popoverMotion.connect("leave", () => {
            popover.hide();
          });

          popover.add_controller(popoverMotion);

          /* ---------- Drop target ---------- */
          const dropTarget = new Gtk.DropTarget({
            actions: Gdk.DragAction.MOVE,
          });

          dropTarget.set_gtypes([GObject.TYPE_INT]);

          dropTarget.connect("enter", () => {
            if (hideTimeout) {
              hideTimeout.cancel();
            }
            popover.show();
            return Gdk.DragAction.MOVE;
          });

          dropTarget.connect("leave", () => {
            popover.hide();
          });

          dropTarget.connect("drop", (_, value: number) => {
            print("DROP TARGET DROP");
            const pid = value;
            print("dropped PID:", pid);
            hyprland.message_async(
              `dispatch movetoworkspacesilent ${id}, pid:${pid}`,
              () => {},
            );

            return true;
          });

          self.add_controller(dropTarget);
        }}
      />
    );
  };

  // Reactive workspace state that updates when workspaces or focus changes
  const workspaces: Accessor<any[]> = createComputed(() => {
    const activeWorkspaces = createBinding(hyprland, "workspaces")();
    const currentWorkspace = focusedWorkspace().id;

    // Create a map of workspace ID to workspace object for quick lookup
    const workspaceMap = new Map(activeWorkspaces.map((w) => [w.id, w]));

    // Get array of active workspace IDs
    const workspaceIds = activeWorkspaces.map((w) => w.id);
    // Calculate total workspaces needed (active ones or maxWorkspaces, whichever is larger)
    const totalWorkspaces = Math.max(...workspaceIds, maxWorkspaces);

    // Create array of all workspaces (active or null for empty)
    const allWorkspaces = Array.from(
      { length: totalWorkspaces },
      (_, i) => workspaceMap.get(i + 1) || null,
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
          </box>,
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
    allWorkspaces.forEach((workspace, index) => {
      const isActive = workspace !== null;

      if (isActive) {
        // ACTIVE WORKSPACE: Add to current group
        currentGroupIsActive = true;
        currentGroup.push(createWorkspaceButton(workspace, index));

        // Close group if this is the last workspace or next one is inactive
        if (
          index === allWorkspaces.length - 1 ||
          allWorkspaces[index + 1] === null
        ) {
          finalizeCurrentGroup();
        }
      } else {
        // INACTIVE WORKSPACE: Close any active group and add as standalone
        finalizeCurrentGroup();
        groupElements.push(
          <box class="workspace-group inactive">
            {createWorkspaceButton(workspace, index)}
          </box>,
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

    allWorkspaces.forEach((workspace, index) => {
      const id = index + 1;
      newStates.set(id, {
        isActive: workspace !== null,
        isFocused: currentWorkspace === id,
      });
    });

    previousWorkspaceStates = newStates;

    return groupElements;
  });

  // Render the workspaces container with bound workspace elements
  return (
    <box class="workspaces-display">
      <For each={workspaces}>
        {(workspace, index: Accessor<number>) => workspace}
      </For>
    </box>
  );
}

const Special = () => (
  <button
    class={specialWorkspace((special) =>
      special ? "special active" : "special inactive",
    )}
    label={workspaceIconMap["special"]}
    onClicked={() =>
      hyprland.message_async(`dispatch togglespecialworkspace`, (res) => {})
    }
    tooltipMarkup={`Special Workspace\n<b>SUPER + S</b>`}
    $={(self) => {
      /* ---------- Drop target ---------- */
      const dropTarget = new Gtk.DropTarget({
        actions: Gdk.DragAction.MOVE,
      });

      dropTarget.set_gtypes([GObject.TYPE_INT]);

      dropTarget.connect("drop", (_, value: number) => {
        print("DROP TARGET DROP");
        const pid = value;
        print("dropped PID:", pid);
        hyprland.message_async(
          `dispatch movetoworkspacesilent special, pid:${pid}`,
          () => {},
        );

        return true;
      });

      self.add_controller(dropTarget);
    }}
  />
);

const OverView = () => (
  <button
    class="overview"
    label={workspaceIconMap["overview"]}
    onClicked={() =>
      hyprland.message_async("dispatch hyprexpo:expo toggle", (res) => {})
    }
    tooltipMarkup={`Overview Mode\n<b>SUPER + SHIFT + TAB</b>`}
  />
);

function WallpaperSwitcher() {
  return (
    <button
      class="wallpaper-switcher"
      label="󰸉"
      onClicked={(self) => {
        const window = app.get_window(
          `wallpaper-switcher-${(self.get_root() as any).monitorName}`,
        );
        if (window)
          window.is_visible()
            ? (window.visible = false)
            : (window.visible = true);
      }}
      tooltipMarkup={`Wallpaper Switcher\n<b>SUPER + W</b>`}
    />
  );
}

function UserPanel() {
  return (
    <button
      class="user-panel"
      label=""
      onClicked={(self) => {
        const window = app.get_window(
          `user-panel-${(self.get_root() as any).monitorName}`,
        );
        if (window)
          window.is_visible()
            ? (window.visible = false)
            : (window.visible = true);
      }}
      tooltipMarkup={`User Panel\n<b>SUPER + ESC</b>`}
    />
  );
}

const Actions = () => {
  return (
    <box class="actions">
      <UserPanel />
      <WallpaperSwitcher />
    </box>
  );
};

export default ({ halign }: { halign?: Gtk.Align | Accessor<Gtk.Align> }) => {
  return (
    <box class="workspaces" spacing={5} halign={halign} hexpand>
      <Actions />
      <OverView />
      <Special />
      <Workspaces />
    </box>
  );
};
