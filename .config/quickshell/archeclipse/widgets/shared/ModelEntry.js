// Model-entry accessors shared by the pill/chip/segment controls: a model is either a list of
// strings (value == label) or objects with value/label/icon/tooltip/enabled aliases.
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
