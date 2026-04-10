import { Gtk } from "ags/gtk4";
import { focusedWorkspace, specialWorkspace } from "../../../variables";

import Hyprland from "gi://AstalHyprland";
import { createBinding, createComputed } from "ags";
import { hideWindow, showWindow } from "../../../utils/window";
import { For } from "ags";
import { Accessor } from "ags";
import app from "ags/gtk4/app";
import { workspaceClientLayoutById } from "../../../utils/workspace";
import { timeout, Timer } from "ags/time";
import { Gdk } from "ags/gtk4";
import GObject from "ags/gobject";

const hyprland = Hyprland.get_default();

const workspaceIconMap: { [name: string]: string } = {
  special: "",
  overview: "󰕬",
  zen: "󰖟",
  firefox: "󰈹",
  code: "",
  foot: "",
  kitty: "",
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
  const hyprlandWorkspaces = createBinding(hyprland, "workspaces");
  const hyprlandClients = createBinding(hyprland as any, "clients");

  const getWorkspaceById = (id: number): Hyprland.Workspace | null => {
    const workspaces = hyprlandWorkspaces();
    return workspaces.find((w) => w.id === id) || null;
  };

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
  const createWorkspaceButton = (id: number) => {
    // Track previous state for this specific button
    let prevState = previousWorkspaceStates.get(id);

    return (
      <button
        class={createComputed(() => {
          const isActive = getWorkspaceById(id) !== null;
          const currentWorkspace = focusedWorkspace().id;
          const isFocused = currentWorkspace === id;

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
          const workspace = getWorkspaceById(id);
          const isActive = workspace !== null;
          if (!isActive) return emptyIcon;

          const clients = (hyprlandClients() || []) as Hyprland.Client[];
          const workspaceClients = clients.filter(
            (client) => client.workspace?.id === id,
          );
          const main_client = workspaceClients[0];
          const client_class = main_client?.class.toLowerCase() || "empty";

          return workspaceIconMap[client_class] || extraWorkspaceIcon;
        })}
        onClicked={() =>
          hyprland.message_async(`dispatch workspace ${id}`, () => {})
        }
        // $={(self) => {
        //   const hasPreview = () => getWorkspaceById(id) !== null;

        //   // --- POPOVER ---
        //   const popover = new Gtk.Popover({
        //     has_arrow: true,
        //     position: Gtk.PositionType.BOTTOM,
        //     autohide: false,
        //   });
        //   popover.set_parent(self);
        //   popover.set_child(workspaceClientLayoutById(id));

        //   // --- HOVER LOGIC ---
        //   let hideTimeout: Timer | null = null;

        //   // Button hover controller
        //   const buttonMotion = new Gtk.EventControllerMotion();

        //   buttonMotion.connect("enter", () => {
        //     if (!hasPreview()) return;

        //     if (hideTimeout) {
        //       hideTimeout.cancel();
        //       hideTimeout = null;
        //     }
        //     popover.popup();
        //   });

        //   buttonMotion.connect("leave", () => {
        //     if (!hasPreview()) return;

        //     // Delay hiding to allow moving to popover
        //     hideTimeout = timeout(180, () => {
        //       popover.popdown();
        //       hideTimeout = null;
        //     });
        //   });

        //   self.add_controller(buttonMotion);

        //   // Popover hover controller
        //   const popoverMotion = new Gtk.EventControllerMotion();

        //   popoverMotion.connect("enter", () => {
        //     if (hideTimeout) {
        //       hideTimeout.cancel();
        //       hideTimeout = null;
        //     }
        //   });

        //   popoverMotion.connect("leave", () => {
        //     popover.popdown();
        //   });

        //   popover.add_controller(popoverMotion);

        //   /* ---------- Drop target ---------- */
        //   const dropTarget = new Gtk.DropTarget({
        //     actions: Gdk.DragAction.MOVE,
        //   });

        //   dropTarget.set_gtypes([GObject.TYPE_OBJECT]);

        //   dropTarget.connect("enter", () => {
        //     // Tooltip
        //     self.set_tooltip_markup(`Move to <b>Workspace ${id}</b>`);

        //     if (!hasPreview()) {
        //       return Gdk.DragAction.MOVE;
        //     }

        //     if (hideTimeout) {
        //       hideTimeout.cancel();
        //       hideTimeout = null;
        //     }
        //     popover.popup();
        //     return Gdk.DragAction.MOVE;
        //   });

        //   dropTarget.connect("leave", () => {
        //     // Disable Tooltip
        //     self.set_tooltip_markup("");

        //     popover.popdown();
        //   });

        //   dropTarget.connect("drop", (_, value: Hyprland.Client) => {
        //     print("DROP TARGET DROP");
        //     const pid = value.pid;
        //     print("dropped PID:", pid);
        //     hyprland.message_async(
        //       `dispatch movetoworkspacesilent ${id}, pid:${pid}`,
        //       () => {},
        //     );

        //     return true;
        //   });

        //   self.add_controller(dropTarget);

        //   self.connect("destroy", () => {
        //     if (hideTimeout) {
        //       hideTimeout.cancel();
        //       hideTimeout = null;
        //     }

        //     popover.popdown();
        //     popover.set_child(null);
        //     popover.unparent();
        //   });
        // }}
      />
    );
  };

  const workspaceIds: Accessor<number[]> = createComputed(() => {
    const activeWorkspaces = hyprlandWorkspaces();
    const visibleIds = new Set<number>();

    for (let id = 1; id <= maxWorkspaces; id++) {
      visibleIds.add(id);
    }

    for (const workspace of activeWorkspaces) {
      if (workspace.id > maxWorkspaces) {
        visibleIds.add(workspace.id);
      }
    }

    return Array.from(visibleIds).sort((a, b) => a - b);
  });

  const workspaceGroups: Accessor<any[]> = createComputed(() => {
    const orderedIds = workspaceIds();
    const groupElements: any[] = [];
    let currentGroup: any[] = [];
    let currentGroupIsActive = false;

    const finalizeCurrentGroup = () => {
      if (currentGroup.length === 0) return;

      groupElements.push(
        <box
          class={`workspace-group ${
            currentGroupIsActive ? "active" : "inactive"
          }`}
        >
          {currentGroup}
        </box>,
      );

      currentGroup = [];
      currentGroupIsActive = false;
    };

    for (const id of orderedIds) {
      const isActive = getWorkspaceById(id) !== null;

      if (isActive) {
        currentGroupIsActive = true;
        currentGroup.push(createWorkspaceButton(id));
      } else {
        finalizeCurrentGroup();
        groupElements.push(
          <box class="workspace-group inactive">
            {createWorkspaceButton(id)}
          </box>,
        );
      }
    }

    finalizeCurrentGroup();

    return groupElements;
  });

  // Render the workspaces container with bound workspace elements
  return (
    <box class="workspaces-display">
      <For each={workspaceGroups}>{(group) => group}</For>
    </box>
  );
}

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

      dropTarget.connect("drop", (_, value: Hyprland.Client) => {
        print("DROP TARGET DROP");
        const pid = value.pid;
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

export default ({ halign }: { halign?: Gtk.Align | Accessor<Gtk.Align> }) => {
  return (
    <box class="workspaces" spacing={5} halign={halign} hexpand>
      <OverView />
      <Special />
      <Workspaces />
    </box>
  );
};
