#!/usr/bin/gjs

import { Gtk } from "ags/gtk4";
import { Accessor } from "gnim";

interface CircularProgressProps {
  value: number; // between 0 and 1
  className?: string;
  height?: number;
  width?: number;
  tooltipText?: string;
  visible?: Accessor<boolean> | boolean;
}

export default function CircularProgress({
  value,
  className = "",
  height = 15,
  width = 15,
  tooltipText,
  visible = true,
}: CircularProgressProps) {
  const drawingArea = new Gtk.DrawingArea({
    width_request: width,
    height_request: height,
  });

  // Draw function reacts to the current `value`
  drawingArea.set_draw_func((area, cr, width, height) => {
    const cx = width / 2;
    const cy = height / 2;
    const radius = Math.min(width, height) / 2 - 1;

    cr.setLineWidth(2);

    // Background circle
    cr.setSourceRGBA(0.5, 0.5, 0.5, 0.5);
    cr.arc(cx, cy, radius, 0, 2 * Math.PI);
    cr.stroke();

    const styleContext = area.get_style_context();
    const fgColor = styleContext.get_color();
    cr.setSourceRGBA(fgColor.red, fgColor.green, fgColor.blue, fgColor.alpha);
    cr.arc(cx, cy, radius, -Math.PI / 2, -Math.PI / 2 + value * 2 * Math.PI);
    cr.stroke();
  });

  // Return the drawingArea wrapped in a box if you want spacing or styling
  return (
    <box
      visible={visible}
      class={`circular-progress ${className}`}
      spacing={5}
      tooltip-text={tooltipText}>
      {drawingArea}
    </box>
  );
}
