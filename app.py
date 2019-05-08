from Question import Question



question_prompts = [
    "what color are apple?\n(a) Green/Red\n(b) Purple\n(c) Yellow\n\n",
    "what color are banana?\n(a) Yellow\n(b) Green\n(c) Blue\n\n",
    "what color are strawberry\n(a) Red\n(b) black\n(c) Grey\n\n",
]

questions = [
    Question(question_prompts[0], "a"),
    Question(question_prompts[1], "a"),
    Question(question_prompts[2], "a")

]


def run_test(questions):
    score = 0
    for question in questions:
        answer = input(question.prompt)
        if answer == question.answer:
            score +=1

    print("Your got" + str(score) + "/" + str(len(questions)) + "correct")

run_test(questions)