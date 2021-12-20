# Binarycr

Trading bot for Binary.com

## Installation

```crystal
crystal build src/binarycr.cr --release
```

## Usage

By default it will alternate between Contract Types, EVEN and ODD
```bash
./binarycr --token=xxx --application=xxx --trade_amount=10 --wanted_profit=100 --stop_loss=256
```

To only place trades in EVEN or ODD you can add an extra parameter to force it to only stay in one type of contract
```bash
./binarycr --token=xxx --application=xxx --trade_amount=10 --wanted_profit=100 --stop_loss=256 --contract=even
```

To display the account balance
```bash
./binarycr --token=xxx --application=xxx --balance
```

## Screenshots

Example of a winning trading session

![binary 01](screenshots/screen_shot_00.png)

## Contributing

1. Fork it (<https://github.com/xtokio/binarycr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Luis Gomez](https://github.com/xtokio) - creator and maintainer
