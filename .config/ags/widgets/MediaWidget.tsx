import Player from "./Player";
import Gtk from "gi://Gtk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import Mpris from "gi://AstalMpris";
import { createBinding, createComputed, With } from "ags";
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

const activePlayer = () => {
  // if (mpris.players.length == 0) return noPlayerFound();

  const player =
    mpris.players.find(
      (player) => player.playbackStatus === Mpris.PlaybackStatus.PLAYING
    ) || mpris.players[0];

  // return Player(player, "widget");
  return <Player player={player} playerType="widget" />;
};

const players = createBinding(mpris, "players");

const Media = () => (
  <box>
    <With value={players}>
      {(players) => (players.length > 0 ? activePlayer() : noPlayerFound())}
    </With>
  </box>
);

export default () => Media();
