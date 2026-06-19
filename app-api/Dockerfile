FROM python:3.11-slim

RUN pip install --no-cache-dir requests Flask gunicorn

COPY potencia-prometehus-cm.py ./
COPY element.ssh ./

EXPOSE 5000

CMD ["gunicorn", "-b", "0.0.0.0:5000", "potencia-prometehus-cm:app"]
