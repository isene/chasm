# The CHasm desktop in a browser tab, with nothing installed on your machine.
#
#   docker run --rm -p 127.0.0.1:6080:6080 ghcr.io/isene/chasm-try
#
# then open http://localhost:6080. Build it yourself from the repo root:
#
#   docker build -f try/Dockerfile -t chasm-try .
#
# Inside, frame draws into memory, x11vnc reads that picture, and noVNC
# shows it in the browser. The desktop is installed the way the README says.
FROM debian:13-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo ca-certificates curl \
        x11vnc novnc websockify procps \
 && useradd -m -s /bin/bash you \
 && echo 'you ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/you \
 && echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/90no-recommends

COPY --chown=you . /home/you/chasm
COPY try/chasm-try /usr/local/bin/chasm-try
COPY try/welcome /usr/local/share/chasm-try/welcome
USER you
WORKDIR /home/you

# sudo is for the install only, and goes once it is done.
RUN chasm/chasm-install --no-greeter \
 && rm -rf chasm \
 && sudo sh -c 'printf "<meta http-equiv=refresh content=\"0;url=vnc.html?autoconnect=1&resize=scale\">\n" \
        > /usr/share/novnc/index.html' \
 && sudo rm -rf /var/lib/apt/lists/* /etc/sudoers.d/you

EXPOSE 6080
CMD ["chasm-try"]
