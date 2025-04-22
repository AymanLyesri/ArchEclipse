import { exec, execAsync } from "astal"
import { notify } from "./notification"
import { Waifu } from "../interfaces/waifu.interface";

const terminalWaifuPath = `$HOME/.config/fastfetch/assets/logo.webp`;

export function getDominantColor(imagePath: string)
{

    return exec(`bash ./scripts/get-image-color.sh ${imagePath}`)

}

export function previewFloatImage(imagePath: string)
{
    execAsync(`swayimg -w 690,690 --class 'previewImage' ${imagePath}`)
        .catch(err => notify({ summary: 'Error', body: err }))
}

export const PinImageToTerminal = (image: Waifu) =>
{
    execAsync(
        `bash -c "[ -f ${terminalWaifuPath} ] && { rm ${terminalWaifuPath}; echo 1; } || { cwebp -q 75 ${image.url_path} -o ${terminalWaifuPath}; echo 0; } && pkill -SIGUSR1 zsh"`
    )
        .then((output) =>
            notify({
                summary: "Waifu",
                body: `${Number(output) == 0 ? "Pinned To Terminal" : "UN-Pinned from Terminal"
                    }`,
            })
        )
        .catch((err) => notify({ summary: "Error", body: err }));
};
