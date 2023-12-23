import { useContext, useEffect } from "react";
import classNames from "classnames";

import { PlexContext } from "./App";

const Toast = () => {
    const {
        toast,
        setToast
	} = useContext(PlexContext)

    useEffect(() => {
        console.log('loaded toast')
        setTimeout(() => {
            setToast({})
        }, 3000);
    }, [])

    return (
        <div id="toast" className={classNames(
            "fixed",
            "top-0",
            "w-full",
            "flex",
            "justify-center",
            "text-3xl",
            "bg-gray-600",
            "p-4",
            "text-white",
            "z-[60]"
        )}>
            {toast.text}
        </div>
    )
}

export default Toast;