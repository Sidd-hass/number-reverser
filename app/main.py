
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, ConfigDict, StrictInt

app = FastAPI(
    title="Number Reverser",
    description="API to reverse the digits of an integer",
    version="1.0.0"
)

# Signed 64-bit integer boundaries
INT64_MIN = -(2**63)
INT64_MAX = 2**63 - 1


class ReverseRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    number: StrictInt


class ReverseResponse(BaseModel):
    input: int
    reversed: int


def reverse_number(number: int) -> int:
    """Reverse integer digits while preserving the sign."""

    if not INT64_MIN <= number <= INT64_MAX:
        raise ValueError("Input exceeds signed 64-bit integer range")

    sign = -1 if number < 0 else 1

    reversed_digits = int(str(abs(number))[::-1])

    result = sign * reversed_digits

    if not INT64_MIN <= result <= INT64_MAX:
        raise ValueError("Reversed result exceeds signed 64-bit integer range")

    return result


@app.get("/", response_class=HTMLResponse)
def home():
    return HTML_PAGE


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/reverse", response_model=ReverseResponse)
def reverse(payload: ReverseRequest):

    try:
        result = reverse_number(payload.number)

    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc)
        ) from exc

    return {
        "input": payload.number,
        "reversed": result
    }


HTML_PAGE = r"""
<!DOCTYPE html>
<html>
<head>
    <title>Number Reverser</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <style>
        body {
            font-family: Arial, sans-serif;
            background: #eef2ff;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
        }

        .container {
            background: white;
            padding: 35px;
            border-radius: 15px;
            width: 90%;
            max-width: 430px;
            box-shadow: 0 10px 35px #00000015;
        }

        h1 {
            text-align: center;
            color: #4338ca;
        }

        input {
            width: 100%;
            padding: 13px;
            margin-top: 10px;
            box-sizing: border-box;
            font-size: 18px;
        }

        button {
            width: 100%;
            padding: 14px;
            margin-top: 15px;
            background: #4f46e5;
            color: white;
            border: none;
            border-radius: 6px;
            font-size: 16px;
            cursor: pointer;
        }

        button:disabled {
            opacity: 0.6;
        }

        #result {
            margin-top: 20px;
            padding: 15px;
            background: #eef2ff;
            border-radius: 8px;
            text-align: center;
            display: none;
        }

        #answer {
            font-size: 28px;
            font-weight: bold;
            color: #4338ca;
        }

        #error {
            color: #b91c1c;
            margin-top: 12px;
        }
    </style>
</head>

<body>

<div class="container">

    <h1>Number Reverser</h1>

    <p>Enter a whole number to reverse its digits.</p>

    <form id="reverseForm">

        <input
            type="text"
            id="number"
            placeholder="Enter a number e.g. 12345"
            required
        >

        <button type="submit" id="submitButton">
            Reverse Number
        </button>

    </form>

    <div id="error"></div>

    <div id="result">
        <p>Reversed Result</p>
        <div id="answer"></div>
    </div>

</div>

<script>

document.getElementById("reverseForm").addEventListener(
    "submit",
    async function(event) {

        event.preventDefault();

        const raw = document.getElementById("number").value.trim();

        const error = document.getElementById("error");
        const result = document.getElementById("result");
        const button = document.getElementById("submitButton");

        error.textContent = "";
        result.style.display = "none";

        if (!/^-?\d+$/.test(raw)) {
            error.textContent = "Please enter a valid whole number.";
            return;
        }

        const number = Number(raw);

        if (!Number.isSafeInteger(number)) {
            error.textContent =
                "Please enter an integer within JavaScript's safe input range.";
            return;
        }

        button.disabled = true;
        button.textContent = "Processing...";

        try {

            const response = await fetch("/reverse", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({ number: number })
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.detail || "Request failed");
            }

            document.getElementById("answer").textContent =
                data.reversed;

            result.style.display = "block";

        } catch (err) {

            error.textContent = err.message;

        } finally {

            button.disabled = false;
            button.textContent = "Reverse Number";

        }

    }
);

</script>

</body>
</html>
"""
