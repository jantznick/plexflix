const Button = ({text, clickHandler}) => {
    return (<button onClick={clickHandler} className="bg-plexYellow hover:bg-plexYellowHover text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline">{text}</button>)
}

export default Button;