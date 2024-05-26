import { useContext } from "react";

import { PlexContext } from "./App";

import Configs from "./Configs";
import Lists from "./Lists";
import TitlePage from "./TitlePage";
import SearchResults from "./SearchResults";

const Interstitial = ({slug}) => {

    const {
        activeTitle,
        setInterstitial,
        setActiveTitle
    } = useContext(PlexContext)

    const handleClose = () => {
        setActiveTitle({});
        setInterstitial(false);
        window.document.getElementsByTagName('body')[0].style.overflowY = '';
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
        case 'title-page':
            title = 'Movie Details';
            children = <TitlePage {...activeTitle} />
            break;
        case 'search-page':
            title = 'Search Results';
            children = <SearchResults />
            break;
    }

    return (
        <div id="interstitial" className="text-white flex" style={{top: window.scrollY + 'px'}}>
            <div className="bg-black w-[90%] lg:w-1/2 m-auto max-h-[75vh] overflow-scroll p-8 flex justify-center flex-wrap scrollbar-hide">
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