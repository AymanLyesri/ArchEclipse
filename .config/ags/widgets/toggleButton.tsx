// import { createState, createComputed } from "ags";

// // Define the props interface for the togglebutton component
// export interface togglebuttonProps {
//   // Callback function triggered when the button is toggled
//   onToggled?: (self: any, on: boolean) => void;

//   // The state of the button can be a boolean or a reactive accessor
//   state?: (() => boolean) | boolean;

//   // The child component inside the button
//   child?: any;
//   [key: string]: any;
// }

// // togglebutton functional component
// export default function togglebutton(btnprops: togglebuttonProps) {
//   // Destructure properties from props, providing default values if needed
//   const { state = false, onToggled, setup, child, ...props } = btnprops;

//   // Create an internal state variable
//   const [innerState, setInnerState] = createState(
//     typeof state === "function" ? state() : state
//   );

//   // Sync innerState with prop state
//   if (typeof state === "function") {
//     setInnerState(state());
//   }

//   return (
//     <button
//       {...props} // Spread other button props
//       class={createComputed(() => {
//         const base = props.className || "";
//         return innerState ? `${base} checked` : base;
//       })}
//       setup={(self) => {
//         setup?.(self); // Call the setup function if provided
//       }}
//       onClicked={(self) => {
//         // Toggle the state and trigger the `onToggled` callback with the new value
//         const newValue = !innerState;
//         setInnerState(newValue);
//         onToggled?.(self, newValue);
//       }}
//       child={child} // Set the button's child element
//     />
//   );
// }
