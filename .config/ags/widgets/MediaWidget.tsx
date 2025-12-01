import Player from "./Player";
import Gtk from "gi://Gtk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import Mpris from "gi://AstalMpris";
import { createBinding, createComputed } from "ags";
const mpris = Mpris.get_default();

const noPlayerFound = () => (
  <box
    halign={Gtk.Align.CENTER}
    valign={Gtk.Align.CENTER}
    hexpand={true}
    class="module"
    child={<label label="No player found" />}
  />
);

const activePlayer = () => {
  if (mpris.players.length == 0) return noPlayerFound();

  const player =
    mpris.players.find(
      (player) => player.playbackStatus === Mpris.PlaybackStatus.PLAYING
    ) || mpris.players[0];

  // return Player(player, "widget");
  return <Player player={player} playerType="widget" />;
};

const players = createBinding(mpris, "players");

const Media = () => (
  <box
    child={createComputed(() =>
      players().length > 0 ? activePlayer() : noPlayerFound()
    )}
  />
);

export default () => Media();
