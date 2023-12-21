import { useContext } from "react";

import { PlexContext } from "./App";

import Configs from "./Configs";
import Lists from "./Lists";

const Interstitial = ({slug}) => {

    const {
        setInterstitial,
    } = useContext(PlexContext)

    const handleClose = () => {
        setInterstitial(false);
    }

    let title, children;
    switch(slug){
        case 'configs':
            title = 'Update Application API Key Settings';
            children = <Configs />;
            break;
        case 'lists':
            title = 'Your Lists';
            children = <Lists />;
            break;
    }

    return (
        <div id="interstitial" className="text-white flex">
            <div className="bg-black w-[90%] md:w-1/2 m-auto p-8 flex justify-center flex-wrap">
                <div className="flex justify-center w-full mb-4">
                    <div className="mr-auto"></div>
                    <div className="font-bold">{title}</div>
                    <span onClick={handleClose} className="material-symbols-outlined ml-auto text-white text-4xl hover:cursor-pointer">close</span>
                </div>
                {children}
            </div>
        </div>
    )
}

export default Interstitial;