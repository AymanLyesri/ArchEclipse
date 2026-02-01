import { Accessor, createBinding, createState, With } from "ags";
import { createPoll } from "ags/time";
import Gtk from "gi://Gtk?version=4.0";
import GLib from "gi://GLib?version=2.0";
import { Eventbox } from "./Custom/Eventbox";
import { Progress } from "./Progress";
import Pango from "gi://Pango";

// Bar characters for the graph ▁ ▂ ▃ ▄ ▅ ▆ ▇ █
const BARS = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"];

// Configuration
const POLL_INTERVAL = 300000; // Poll every 5 minutes (adjust as needed)

function updateGraph(prices: number[], maxPoints: number): string {
  if (prices.length === 0) return "▁".repeat(maxPoints);

  // Take the last maxPoints prices
  const recentPrices = prices.slice(-maxPoints);

  // Pad if needed
  const paddedPrices = [
    ...Array(maxPoints - recentPrices.length).fill(recentPrices[0] || 0),
    ...recentPrices,
  ];

  // Sort to find percentile ranges for better distribution
  const sorted = [...paddedPrices].sort((a, b) => a - b);

  // Map each price to a bar based on its position in the sorted array
  return paddedPrices
    .map((p) => {
      // Find where this price ranks (percentile)
      const rank = sorted.filter((x) => x <= p).length;
      const percentile = rank / sorted.length;
      // Map percentile directly to bar index
      const barIndex = Math.min(7, Math.floor(percentile * 8));
      return BARS[barIndex];
    })
    .join("");
}

function trendColor(prices: number[]): string {
  if (prices.length < 2) return "neutral";
  return prices.at(-1)! >= prices[0] ? "up" : "down";
}

function Crypto({
  symbol = "btc",
  timeframe = "7d",
  showPrice = true,
  showGraph = true,
  orientation = Gtk.Orientation.VERTICAL,
  barNumber = 10,
}: {
  symbol?: string;
  timeframe?: string;
  showPrice?: boolean;
  showGraph?: boolean;
  orientation?: Gtk.Orientation;
  barNumber?: number;
}) {
  // State for prices and current value
  const [getPrices, setPrices] = createState<number[]>([]);
  const [getCurrentPrice, setCurrentPrice] = createState<number>(0);
  const [progressStatus, setProgressStatus] = createState<
    "loading" | "error" | "success" | "idle"
  >("loading");
  const [getPriceChange, setPriceChange] = createState<{
    change: number;
    percent: number;
  }>({ change: 0, percent: 0 }); // Create the graph string from prices
  //   const graph = createComputed(() => updateGraph(getPrices.get()));
  const graph = getPrices((prices) => updateGraph(prices, barNumber));

  // Determine color based on trend
  //   const colorClass = createComputed(() => trendColor(getPrices.get()));
  const colorClass = getPrices((prices) => trendColor(prices));

  // Format current price
  const formattedPrice = getCurrentPrice((price) => {
    if (price === 0) return "Loading...";
    return `$${price.toLocaleString("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })}`;
  });

  // Format change with sign
  const formattedChange = getPriceChange((change) => {
    const sign = change.change >= 0 ? "+" : "";
    return `${sign}${change.change.toFixed(2)} (${sign}${change.percent.toFixed(
      2,
    )}%)`;
  });

  // Poll for crypto prices
  const cryptoPoll = createPoll(
    { price: 0, prices: [] },
    POLL_INTERVAL,
    ["python", "./scripts/crypto.py", symbol, timeframe],
    (out) => {
      try {
        const parsed = JSON.parse(out);

        if (!parsed.prices || !Array.isArray(parsed.prices)) {
          console.error("Invalid crypto data format");
          setProgressStatus("error");
          return { price: 0, prices: [] };
        }

        // Extract prices from the API response
        const prices = parsed.prices.map((p: any) => p.price);
        const currentPrice = prices.length > 0 ? prices[prices.length - 1] : 0;

        // Calculate price change if we have previous data
        let change = 0;
        let percent = 0;
        if (prices.length >= 2) {
          const firstPrice = prices[0];
          const lastPrice = prices[prices.length - 1];
          change = lastPrice - firstPrice;
          percent = (change / firstPrice) * 100;
        }

        // Update states
        setPrices(prices);
        setCurrentPrice(currentPrice);
        setPriceChange({ change, percent });
        setProgressStatus("success");

        return { price: currentPrice, prices };
      } catch (e) {
        console.error("Failed to parse crypto data:", e);
        setProgressStatus("error");
        return { price: 0, prices: [] };
      }
    },
  );

  // Create the widget
  return (
    <Eventbox
      onClick={() => {
        // Open a crypto-related page when clicked
        GLib.spawn_command_line_async(
          `xdg-open https://www.coingecko.com/en/coins/${symbol}`,
        );
      }}
      onHover={() => {
        // Optional: Show tooltip or additional info on hover
      }}
    >
      <box
        class={colorClass((c) => `crypto ${c}`)}
        spacing={4}
        orientation={orientation}
      >
        {/* Hidden label to ensure cryptoPoll runs */}

        <label visible={false} label={cryptoPoll(() => "")} />

        <With value={getCurrentPrice}>
          {(price) =>
            price === 0 ? (
              <Progress
                status={progressStatus}
                custom_class="crypto-loading"
                transitionType={Gtk.RevealerTransitionType.NONE}
              />
            ) : (
              <box spacing={2}>
                {showPrice && (
                  <box spacing={2}>
                    <label class="crypto-symbol" label={symbol.toUpperCase()} />

                    <label
                      class="crypto-price"
                      label={formattedPrice}
                      ellipsize={Pango.EllipsizeMode.END}
                    />
                    {/* <label
                    class={colorClass((c) => `crypto-change ${c}`)}
                    label={formattedChange}
                  /> */}
                  </box>
                )}

                {showGraph && (
                  <label
                    class={colorClass((c) => `crypto-graph mono ${c}`)}
                    label={graph}
                    xalign={0}
                    hexpand={false}
                  />
                )}
              </box>
            )
          }
        </With>
      </box>
    </Eventbox>
  );
}

export default Crypto;
