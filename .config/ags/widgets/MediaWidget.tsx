import Player from "./Player";
import Gtk from "gi://Gtk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import Mpris from "gi://AstalMpris";
import { Accessor, createBinding, createComputed, With } from "ags";
const mpris = Mpris.get_default();

const noPlayerFound = () => (
  <box
    halign={Gtk.Align.CENTER}
    valign={Gtk.Align.CENTER}
    hexpand={true}
    class="module"
  >
    <label label="No player found" />
  </box>
);

const players = createBinding(mpris, "players");

export default function ({
  width,
  height,
  className,
}: {
  width?: Accessor<number> | number;
  height?: Accessor<number> | number;
  className?: string | Accessor<string>;
}) {
  return (
    <box css={"border-radius: 10px;"}>
      <With value={players}>
        {(players) =>
          players.length > 0 ? (
            <Player
              width={width}
              height={height}
              player={
                mpris.players.find(
                  (player) =>
                    player.playbackStatus === Mpris.PlaybackStatus.PLAYING,
                ) || mpris.players[0]
              }
            />
          ) : (
            noPlayerFound()
          )
        }
      </With>
    </box>
  );
}
