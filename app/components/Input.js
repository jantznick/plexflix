const Input = ({
    handleChange,
    width,
    ...props
}) => {

    return (<input
        {...props}
        onChange={e => handleChange(e.target.value)}
        className={`shadow appearance-none border rounded w-${width} py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline disabled:text-gray-300`}
    />)
}

export default Input;