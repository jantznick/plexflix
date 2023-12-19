import Title from "./Title";

const Row = ({title, mediaProvidedBy, titles}) => {

    return (
        <div className="text-white">
            <div className="">
                <span className="">{title}</span><span className="">Provided by: {mediaProvidedBy}</span>
            </div>
            <div id="media-tray" className="flex overflow-scroll h-80 space-x-4">
                    {titles.map(title =>
                        <Title {...title} />
                    )}
            </div>
        </div>
    )
}

export default Row;