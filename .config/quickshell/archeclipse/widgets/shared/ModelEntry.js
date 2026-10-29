// Model-entry accessors shared by the pill/chip/segment controls.
//
// A control model is either a list of strings (value == label, always
// enabled, no tooltip/icon) or a list of objects using the field aliases the
// call sites already used:
//   value   <- value | display | name | the object itself
//   label   <- label | display | name | String(value)
//   icon    <- icon
//   tooltip <- tooltip | tooltipText
//   enabled <- enabled (default true)
//
// Out-of-range indexes read as undefined/""/false so delegates created
// during a model swap can never throw.
function _at(model, i) {
    if (!model || i < 0 || i >= model.length)
        return undefined;
    return model[i];
}

function valueAt(model, i) {
    const e = _at(model, i);
    if (e === undefined)
        return undefined;
    if (typeof e === "string")
        return e;
    return e?.value ?? e?.display ?? e?.name ?? e;
}

function labelAt(model, i) {
    const e = _at(model, i);
    if (e === undefined)
        return "";
    if (typeof e === "string")
        return e;
    return e?.label ?? e?.display ?? e?.name ?? String(e?.value ?? "");
}

function iconAt(model, i) {
    const e = _at(model, i);
    if (e === undefined || typeof e === "string")
        return "";
    return e?.icon ?? "";
}

function tooltipAt(model, i) {
    const e = _at(model, i);
    if (e === undefined || typeof e === "string")
        return "";
    return e?.tooltip ?? e?.tooltipText ?? "";
}

function enabledAt(model, i) {
    const e = _at(model, i);
    if (e === undefined)
        return false;
    if (typeof e === "string")
        return true;
    return e?.enabled ?? true;
}
