FROM whiteregistry.cuyows.tcloud.ar/whitecicd-pipeline/python-sfp-base:3.11

COPY potencia-prometehus-cm.py ./
COPY element.ssh ./

EXPOSE 5000

CMD ["gunicorn", "-b", "0.0.0.0:5000", "potencia-prometehus-cm:app"]
