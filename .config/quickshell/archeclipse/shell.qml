//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.bar
import qs.services

ShellRoot {
    Ipc {}

    Variants {
        model: Quickshell.screens

        Bar {
            required property ShellScreen modelData
            screen: modelData
        }
    }
}
