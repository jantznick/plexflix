FROM python:3.12-slim

WORKDIR /app

COPY scores/ /app/scores/
COPY data/ /app/data/

ENV HOST=0.0.0.0
ENV PORT=8096
ENV PYTHONUNBUFFERED=1

EXPOSE 8096

CMD ["python", "-m", "scores"]
