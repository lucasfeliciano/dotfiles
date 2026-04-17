# Kill process on given port.
function kp() {
  lsof -P | grep $1 | awk '{print $2}' | xargs kill -9
}
