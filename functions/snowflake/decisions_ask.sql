parse_json({{ function('decisions_ask_json') }}(to_json(state), to_json(questions)))
