const Input = ({
    name,
    type,
    onChange,
    width,
    value,
    disabled
}) => (
    <input type={type} name={name} onChange={e => onChange(e.target.value)} className={`shadow appearance-none border rounded w-${width} py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline disabled:text-gray-300`} {...value ? value={value} : null} {...disabled ? disabled={disabled} : null} />
)

export default Input;