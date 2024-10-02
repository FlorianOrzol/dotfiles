function conky_my_function()
    -- Ihr Code hier
    return "Ergebnis"
end

function conky_format(format, number)
    return string.format(format, conky_parse(number))
end