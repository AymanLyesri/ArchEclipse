interface KeyBindProps {
  bindings: string[];
  className?: string;
  onButtonClick?: (binding: string, index: number) => void;
}

export default function ({
  bindings,
  className = "",
  onButtonClick,
}: KeyBindProps) {
  return (
    <box class={`keybind ${className}`} spacing={5}>
      {bindings.map((binding, index) => (
        <>
          <button
            class="binding"
            onClicked={() => {
              if (onButtonClick) {
                onButtonClick(binding, index);
              }
            }}
          >
            <label label={binding} />
          </button>
          {index < bindings.length - 1 && <label label="+" />}
        </>
      ))}
    </box>
  );
}
