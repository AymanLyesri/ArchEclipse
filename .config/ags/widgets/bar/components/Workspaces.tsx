import Gtk from "gi://Gtk?version=3.0";
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
  // Track the previously focused workspace for transition effects
  let previousWorkspace = 0;

  // Icons configuration
  const emptyIcon = ""; // Icon for empty workspaces
  const extraWorkspaceIcon = ""; // Icon for workspaces beyond maxWorkspaces
  const maxWorkspaces = 10; // Maximum number of workspaces with custom icons

  /**
   * Creates a workspace button element with proper classes and click handler
   * @param id - Workspace ID number
   * @param isActive - Whether the workspace contains windows
   * @param isFocused - Whether the workspace is currently focused
   * @param icon - The icon to display for this workspace
   * @returns A button element for the workspace
   */
  const createWorkspaceButton = (
    id: number,
    isActive: boolean,
    isFocused: boolean,
    icon: string
  ) => {
    // Determine button classes based on state
    const buttonClass = [
      isFocused ? (previousWorkspace !== id ? "focused" : "same-focused") : "",
      previousWorkspace === id ? "unfocused" : "",
      isActive ? "" : "inactive",
    ]
      .filter(Boolean) // Remove empty strings
      .join(" "); // Combine into space-separated string

    return (
      <button
        class={buttonClass}
        label={icon}
        onClicked={() =>
          hyprland.message_async(`dispatch workspace ${id}`, () => {})
        }
      />
    );
  };

  // Reactive workspace state that updates when workspaces or focus changes
  const workspaces: Accessor<any[]> = createComputed(
    [
      createBinding(hyprland, "workspaces"), // Bind to Hyprland workspace list
      focusedWorkspace.as((w) => w.id), // Bind to currently focused workspace ID
    ],
    (workspaces, currentWorkspace) => {
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
      const groupElements: any[] = [];
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

      // Process each workspace in order
      allWorkspaces.forEach((id) => {
        const isActive = workspaceIds.includes(id); // Does workspace have windows?
        // Determine which icon to use based on workspace state
        const icon =
          id > maxWorkspaces
            ? extraWorkspaceIcon
            : isActive
            ? workspaceToIcon[id]
            : emptyIcon;
        const isFocused = currentWorkspace === id; // Is this the current workspace?

        // Handle inactive workspaces (no windows)
        if (isActive) {
          // If we get here, workspace is active
          currentGroupIsActive = true;
          // Add button to current group
          currentGroup.push(
            createWorkspaceButton(id, isActive, isFocused, icon)
          );

          // Finalize group if we've reached the end or next workspace is inactive
          if (id === allWorkspaces.length || !workspaceIds.includes(id + 1)) {
            finalizeCurrentGroup();
          }
        } else {
          // Finalize any active group we were building
          finalizeCurrentGroup();
          // Add inactive workspace as single-element group
          groupElements.push(
            <box
              class="workspace-group inactive"
              child={createWorkspaceButton(id, isActive, isFocused, icon)}
            />
          );
        }
      });
      previousWorkspace = currentWorkspace; // Update previous workspace for next render

      return groupElements;
    }
  );

  // Render the workspaces container with bound workspace elements
  return (
    <box class="workspaces">
      <For each={workspaces}>
        {(workspace, index: Accessor<number>) => workspace}
      </For>
    </box>
  );
}
const Special = (
  <button
    class="special"
    label={workspaceToIcon[0]}
    onClicked={() =>
      hyprland.message_async(`dispatch togglespecialworkspace`, (res) => {})
    }
  />
);

const OverView = (
  <button
    class="overview"
    label="󱗼"
    onClicked={() =>
      hyprland.message_async("dispatch hyprexpo:expo toggle", (res) => {})
    }
  />
);

function AppLauncher({ monitorName }: { monitorName: string }) {
  return (
    <togglebutton
      class="app-search"
      label=""
      onToggled={({ active }) => {
        on
          ? showWindow(`app-launcher-${monitorName}`)
          : hideWindow(`app-launcher-${monitorName}`);
      }}
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
        on
          ? showWindow(`wallpaper-switcher-${monitorName}`)
          : hideWindow(`wallpaper-switcher-${monitorName}`);
      }}
    />
  );
}

function Settings({ monitorName }: { monitorName: string }) {
  return (
    <togglebutton
      class="settings"
      label=""
      onToggled={({ active }) =>
        on
          ? showWindow(`settings-${monitorName}`)
          : hideWindow(`settings-${monitorName}`)
      }
    />
  );
}

function UserPanel({ monitorName }: { monitorName: string }) {
  return (
    <togglebutton
      class="user-panel"
      label=""
      onToggled={({ active }) => {
        on
          ? showWindow(`user-panel-${monitorName}`)
          : hideWindow(`user-panel-${monitorName}`);
      }}
    />
  );
}

const Actions = ({ monitorName }: { monitorName: string }) => {
  return (
    <box class="actions">
      <UserPanel monitorName={monitorName} />
      <Settings monitorName={monitorName} />
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
      {OverView}
      {Special}
      <Workspaces />
    </box>
  );
};
