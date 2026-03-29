import { execAsync } from "ags/process";
import GLib from "gi://GLib";

import { LauncherApp } from "../../../interfaces/app.interface";
import { readJSONFile, writeJSONFile } from "../../../utils/json";
import { notify } from "../../../utils/notification";

const NOTES_PATH = `${GLib.get_home_dir()}/.config/ags/cache/launcher/notes.json`;
const NOTE_PREVIEW_MAX_LENGTH = 80;

type NoteEntry = {
  id: number;
  content: string;
  createdAt: number;
  updatedAt: number;
};

type NoteCommand =
  | { action: "list" }
  | { action: "add"; content: string }
  | { action: "update"; index: number; content: string }
  | { action: "remove"; index: number };

type NoteResultOptions = {
  prefillEntry?: (value: string) => void;
};

const truncate = (value: string, maxLength: number): string => {
  if (value.length <= maxLength) return value;
  return `${value.slice(0, maxLength - 1)}…`;
};

const normalizeNotes = (value: unknown): NoteEntry[] => {
  if (!Array.isArray(value)) return [];

  return value
    .map((note: Partial<NoteEntry>, index) => {
      const content =
        typeof note.content === "string" ? note.content.trim() : "";
      if (!content) return null;

      const fallbackTime = Date.now() - index;
      const createdAt =
        typeof note.createdAt === "number" ? note.createdAt : fallbackTime;
      const updatedAt =
        typeof note.updatedAt === "number" ? note.updatedAt : createdAt;

      return {
        id: typeof note.id === "number" ? note.id : 0,
        content,
        createdAt,
        updatedAt,
      };
    })
    .filter((note): note is NoteEntry => Boolean(note))
    .sort((a, b) => a.createdAt - b.createdAt)
    .map((note, index) => ({
      ...note,
      id: index + 1,
    }));
};

const readNotes = (): NoteEntry[] =>
  normalizeNotes(readJSONFile<unknown>(NOTES_PATH, []));

const persistNotes = (notes: NoteEntry[]) => {
  writeJSONFile(NOTES_PATH, notes);
};

const toListResults = (
  notes: NoteEntry[],
  maxItems: number,
  options?: NoteResultOptions,
): LauncherApp[] => {
  const visibleNotes = notes.slice(0, maxItems);

  if (visibleNotes.length <= 0) {
    return [
      {
        app_name: "No notes yet",
        app_description: "Type: note buy milk",
        app_icon: "󰎚",
        app_launch: () => {},
      },
    ];
  }

  return visibleNotes.map((note, index) => {
    const noteNumber = note.id;

    return {
      app_name: `${noteNumber}. ${truncate(note.content, NOTE_PREVIEW_MAX_LENGTH)}`,
      app_description: `Updated ${new Date(note.updatedAt).toLocaleString()}`,
      app_icon: "󰎚",
      app_type: "note",
      app_actions: [
        {
          label: "",
          className: "note-action-btn-edit",
          tooltip: `Edit note #${noteNumber}`,
          onClick: () => {
            if (!options?.prefillEntry) {
              notify({
                summary: "Notes",
                body: "Type: note edit <number> <new text>",
              });
              return;
            }

            options.prefillEntry(`note edit ${noteNumber} ${note.content}`);
          },
        },
        {
          label: "",
          className: "note-action-btn-delete",
          tooltip: `Delete note #${noteNumber}`,
          onClick: () => {
            const nextNotes = readNotes();
            const targetIndex = noteNumber - 1;

            if (targetIndex < 0 || targetIndex >= nextNotes.length) {
              notify({ summary: "Notes", body: "Note not found" });
              return;
            }

            nextNotes.splice(targetIndex, 1);
            persistNotes(nextNotes);
            notify({ summary: "Notes", body: "Note removed" });

            options?.prefillEntry?.("note ");
          },
        },
      ],
      app_launch: () => {
        execAsync(["wl-copy", note.content]).catch((err) => {
          notify({
            summary: "Notes",
            body: err instanceof Error ? err.message : String(err),
          });
        });
      },
    };
  });
};

export const parseNoteQuery = (value: string): NoteCommand | null => {
  const normalized = value.trimStart();
  if (!/^note /i.test(normalized)) return null;

  const rawCommand = normalized.slice("note".length).trim();
  if (!rawCommand || /^list$/i.test(rawCommand)) {
    return { action: "list" };
  }

  const updateMatch = rawCommand.match(
    /^(?:edit|set|update|modify)\s+(\d+)(?:\s+([\s\S]+))?$/i,
  );
  if (updateMatch) {
    return {
      action: "update",
      index: Number(updateMatch[1]),
      content: (updateMatch[2] || "").trim(),
    };
  }

  const removeMatch = rawCommand.match(/^(?:del|rm|remove|delete)\s+(\d+)$/i);
  if (removeMatch) {
    return {
      action: "remove",
      index: Number(removeMatch[1]),
    };
  }

  const addMatch = rawCommand.match(/^(?:add|new)\s+([\s\S]+)$/i);
  if (addMatch) {
    return {
      action: "add",
      content: addMatch[1].trim(),
    };
  }

  return {
    action: "add",
    content: rawCommand,
  };
};

export const getNoteResults = (
  command: NoteCommand,
  maxItems: number,
  options?: NoteResultOptions,
): LauncherApp[] => {
  const notes = readNotes();

  if (command.action === "list") {
    return toListResults(notes, maxItems, options);
  }

  if (command.action === "add") {
    const content = command.content.trim();
    if (!content) {
      return [
        {
          app_name: "Note content is empty",
          app_description: "Type: note buy milk",
          app_icon: "󰎚",
          app_launch: () => {},
        },
      ];
    }

    return [
      {
        app_name: `Add note: ${truncate(content, NOTE_PREVIEW_MAX_LENGTH)}`,
        app_description: "Press Enter to save",
        app_icon: "",
        app_close_on_launch: false,
        app_launch: () => {
          const nextNotes = readNotes();
          const timestamp = Date.now();

          nextNotes.push({
            id: nextNotes.length + 1,
            content,
            createdAt: timestamp,
            updatedAt: timestamp,
          });

          persistNotes(nextNotes);
          notify({ summary: "Notes", body: "Note added" });
          options?.prefillEntry?.("note ");
        },
      },
      ...toListResults(notes, Math.max(0, maxItems - 1), options),
    ];
  }

  const targetIndex = command.index - 1;
  if (
    !Number.isInteger(targetIndex) ||
    targetIndex < 0 ||
    targetIndex >= notes.length
  ) {
    return [
      {
        app_name: `Note #${command.index} not found`,
        app_description: "Use: note list",
        app_icon: "󰎚",
        app_launch: () => {},
      },
      ...toListResults(notes, Math.max(0, maxItems - 1), options),
    ];
  }

  if (command.action === "remove") {
    const targetNote = notes[targetIndex];

    return [
      {
        app_name: `Remove note #${command.index}`,
        app_description: truncate(targetNote.content, NOTE_PREVIEW_MAX_LENGTH),
        app_icon: "󰩺",
        app_close_on_launch: false,
        app_launch: () => {
          const nextNotes = readNotes();
          const refreshedTarget = nextNotes[targetIndex];
          if (!refreshedTarget) {
            notify({ summary: "Notes", body: "Note not found" });
            return;
          }

          nextNotes.splice(targetIndex, 1);
          persistNotes(nextNotes);
          notify({ summary: "Notes", body: "Note removed" });
          options?.prefillEntry?.("note ");
        },
      },
      ...toListResults(notes, Math.max(0, maxItems - 1), options),
    ];
  }

  const content = command.content.trim();
  if (!content) {
    return [
      {
        app_name: "Updated note content is empty",
        app_description: `Use: note edit ${command.index} your text`,
        app_icon: "󰎚",
        app_launch: () => {},
      },
      ...toListResults(notes, Math.max(0, maxItems - 1), options),
    ];
  }

  const targetNote = notes[targetIndex];

  return [
    {
      app_name: `Update note #${command.index}`,
      app_description: truncate(content, NOTE_PREVIEW_MAX_LENGTH),
      app_icon: "󰛿",
      app_close_on_launch: false,
      app_launch: () => {
        const nextNotes = readNotes();
        const refreshedTarget = nextNotes[targetIndex];
        if (!refreshedTarget) {
          notify({ summary: "Notes", body: "Note not found" });
          return;
        }

        nextNotes[targetIndex] = {
          ...refreshedTarget,
          content,
          updatedAt: Date.now(),
        };

        persistNotes(nextNotes);
        notify({ summary: "Notes", body: "Note updated" });
        options?.prefillEntry?.("note ");
      },
    },
    {
      app_name: `Current: ${truncate(targetNote.content, NOTE_PREVIEW_MAX_LENGTH)}`,
      app_description: "Existing note",
      app_icon: "󰎚",
      app_launch: () => {},
    },
    ...toListResults(notes, Math.max(0, maxItems - 2), options),
  ];
};
