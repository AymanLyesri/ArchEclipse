import Gtk from "gi://Gtk?version=4.0";
import { Accessor, createState, For, With } from "ags";
import { execAsync } from "ags/process";
import {
  globalSettings,
  globalTransition,
  setGlobalSetting,
} from "../../../variables";
import { notify } from "../../../utils/notification";
import { readJSONFile, writeJSONFile } from "../../../utils/json";
import { Eventbox } from "../../Custom/Eventbox";
import Crypto from "../../Crypto";

// Interfaces
interface CryptoEntry {
  id: string;
  symbol: string;
  timeframe: string;
  showPrice: boolean;
  showGraph: boolean;
}

// Available timeframes
const timeframes = ["1h", "24h", "7d", "30d", "90d", "1y"];

// Variables
const [cryptoEntries, setCryptoEntries] = createState<CryptoEntry[]>([]);
const [showAddForm, setShowAddForm] = createState(false);
const [editingEntry, setEditingEntry] = createState<CryptoEntry | null>(null);

// Storage functions
const saveEntriesToFile = async (entries: CryptoEntry[]) => {
  try {
    await execAsync(`mkdir -p ./assets/crypto`);
    writeJSONFile("./assets/crypto/entries.json", entries);
  } catch (error) {
    console.error("Failed to save crypto entries:", error);
  }
};

const loadEntriesFromFile = async (): Promise<CryptoEntry[]> => {
  try {
    const result = readJSONFile("./assets/crypto/entries.json");
    return Array.isArray(result) ? result : [];
  } catch (error) {
    console.error("Failed to load crypto entries:", error);
    return [];
  }
};

// Initialize entries on load
loadEntriesFromFile().then((entries) => {
  setCryptoEntries(entries);
});

// Entry form component
const CryptoForm = ({
  entry,
  isEdit = false,
}: {
  entry?: CryptoEntry;
  isEdit?: boolean;
}) => {
  const [symbolEntry, setSymbolEntry] = createState(entry?.symbol || "btc");
  const [selectedTimeframe, setSelectedTimeframe] = createState(
    entry?.timeframe || "7d"
  );
  const [showPriceToggle, setShowPriceToggle] = createState(
    entry?.showPrice ?? true
  );
  const [showGraphToggle, setShowGraphToggle] = createState(
    entry?.showGraph ?? true
  );

  const saveEntry = () => {
    const symbol = symbolEntry.get().trim().toLowerCase();

    if (!symbol) {
      notify({
        summary: "Crypto Display",
        body: "Please enter a valid symbol",
      });
      return;
    }

    const newEntry: CryptoEntry = {
      id: entry?.id || Date.now().toString(),
      symbol,
      timeframe: selectedTimeframe.get(),
      showPrice: showPriceToggle.get(),
      showGraph: showGraphToggle.get(),
    };

    const entries = cryptoEntries.get();
    const updatedEntries = isEdit
      ? entries.map((e) => (e.id === entry!.id ? newEntry : e))
      : [...entries, newEntry];

    setCryptoEntries(updatedEntries);
    saveEntriesToFile(updatedEntries);
    setShowAddForm(false);
    setEditingEntry(null);

    notify({
      summary: "Crypto Display",
      body: `${symbol.toUpperCase()} ${
        isEdit ? "updated" : "added"
      } successfully`,
    });
  };

  const cancelForm = () => {
    setShowAddForm(false);
    setEditingEntry(null);
  };

  return (
    <box
      class="form-container crypto-form"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={8}
    >
      <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
        <label
          class="form-label"
          label="Crypto Symbol"
          halign={Gtk.Align.START}
        />
        <entry
          text={symbolEntry}
          placeholderText="e.g. btc, eth, sol"
          $={(self) => {
            self.connect("changed", () => setSymbolEntry(self.text));
          }}
        />
      </box>

      <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
        <label class="form-label" label="Timeframe" halign={Gtk.Align.START} />
        <scrolledwindow hexpand vscrollbarPolicy={Gtk.PolicyType.NEVER}>
          <box class="timeframes" spacing={4} valign={Gtk.Align.START}>
            {timeframes.map((tf) => (
              <togglebutton
                class="timeframe"
                label={tf}
                vexpand={false}
                active={selectedTimeframe((current) => current === tf)}
                onToggled={(self) => {
                  if (self.active) {
                    setSelectedTimeframe(tf);
                  }
                }}
              />
            ))}
          </box>
        </scrolledwindow>
      </box>

      <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
        <label
          class="form-label"
          label="Display Options"
          halign={Gtk.Align.START}
        />
        <box spacing={8}>
          <box spacing={4}>
            <togglebutton
              class="option-toggle"
              label="Show Price"
              active={showPriceToggle}
              onToggled={() => setShowPriceToggle(!showPriceToggle.get())}
            />
          </box>
          <box spacing={4}>
            <togglebutton
              class="option-toggle"
              label="Show Graph"
              active={showGraphToggle}
              onToggled={() => setShowGraphToggle(!showGraphToggle.get())}
            />
          </box>
        </box>
      </box>

      <box class="form-actions" spacing={8}>
        <button
          class="success"
          label={isEdit ? "✓ Update" : "+ Add Crypto"}
          onClicked={saveEntry}
          hexpand
        />
        <button class="danger" label="✕ Cancel" onClicked={cancelForm} />
      </box>
    </box>
  );
};

// Crypto entry item component
const CryptoEntryItem = ({ entry }: { entry: CryptoEntry }) => {
  const [isHovered, setIsHovered] = createState(false);

  const deleteEntry = () => {
    const updatedEntries = cryptoEntries.get().filter((e) => e.id !== entry.id);
    setCryptoEntries(updatedEntries);
    saveEntriesToFile(updatedEntries);
    notify({
      summary: "Crypto Display",
      body: `${entry.symbol.toUpperCase()} removed`,
    });
  };

  const editEntry = () => {
    setEditingEntry(entry);
    setShowAddForm(true);
  };

  const pingEntry = () => {
    setGlobalSetting("crypto.favorite", {
      symbol: entry.symbol,
      timeframe: entry.timeframe,
    });
    notify({
      summary: "Crypto Display",
      body: `${entry.symbol.toUpperCase()} pinned to top bar`,
    });
  };

  return (
    <Eventbox
      class="crypto-entry-eventbox"
      onHover={() => setIsHovered(true)}
      onHoverLost={() => setIsHovered(false)}
    >
      <box
        class="crypto-entry"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={6}
      >
        <box class="crypto-entry-header">
          <box class="crypto-entry-info">
            {/* <label
              class="crypto-symbol"
              label={entry.symbol.toUpperCase()}
              hexpand
              halign={Gtk.Align.START}
            /> */}

            <label
              class="crypto-timeframe"
              label={entry.timeframe + " timeframe"}
            />
          </box>

          <box hexpand />

          <revealer
            revealChild={isHovered}
            transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
            transitionDuration={globalTransition}
          >
            <box class="crypto-entry-actions">
              <button label="" onClicked={pingEntry} />
              <button label="" onClicked={editEntry} />
              <button label="✕" onClicked={deleteEntry} />
            </box>
          </revealer>
        </box>

        <box class="crypto-widget-container">
          <With value={globalSettings(({ rightPanel }) => rightPanel.width)}>
            {(width: number) => (
              <Crypto
                symbol={entry.symbol}
                timeframe={entry.timeframe}
                showPrice={entry.showPrice}
                showGraph={entry.showGraph}
                barNumber={Math.floor(width / 15)}
                orientation={Gtk.Orientation.VERTICAL}
              />
            )}
          </With>
        </box>
      </box>
    </Eventbox>
  );
};

// Main component
const CryptoWidget = ({
  className,
}: {
  className?: string | Accessor<string>;
}) => {
  const toggleForm = () => {
    setEditingEntry(null);
    setShowAddForm(!showAddForm.get());
  };

  return (
    <box
      class={`crypto-widget ${className ?? ""}`}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={5}
    >
      <box class="header">
        <label
          class="title"
          label="Crypto Tracker"
          hexpand
          halign={Gtk.Align.START}
        />
        <button
          class="add-btn"
          label={showAddForm((show) => (show ? "✕" : "+"))}
          onClicked={toggleForm}
        />
      </box>

      <revealer
        revealChild={showAddForm}
        transitionType={Gtk.RevealerTransitionType.SWING_DOWN}
        transitionDuration={globalTransition}
      >
        <With value={editingEntry}>
          {(entry) =>
            entry ? CryptoForm({ entry, isEdit: true }) : CryptoForm({})
          }
        </With>
      </revealer>

      <scrolledwindow class="crypto-list" vexpand>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
          <For each={cryptoEntries}>
            {(entry) => CryptoEntryItem({ entry })}
          </For>
        </box>
      </scrolledwindow>
    </box>
  );
};

export default CryptoWidget;
