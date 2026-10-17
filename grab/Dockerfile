FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app
COPY grab/grab /app/grab

ENV PORT=8097
EXPOSE 8097

HEALTHCHECK --interval=30s --timeout=5s \
    CMD python3 -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/healthz' % os.environ.get('PORT','8097'), timeout=3)"

CMD ["python3", "-m", "grab.server"]
