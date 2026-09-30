from decimal import Decimal


def cart_summary(items):
    subtotal = Decimal('0')
    for item in items:
        product = item['product']
        item['available'] = product is not None and product.get('active', True) and product['stock'] >= item['quantity']
        if product is not None:
            amount = Decimal(str(product['price'])) * item['quantity']
            item['line_total'] = format(amount, '.2f')
            subtotal += amount
        else:
            item['line_total'] = None
    return {'items': items, 'subtotal': format(subtotal, '.2f'), 'total': format(subtotal, '.2f'),
            'can_checkout': bool(items) and all(i['available'] for i in items) and len({i['product'].get('merchant_id') for i in items if i['product']}) <= 1, 'single_merchant': len({i['product'].get('merchant_id') for i in items if i['product']}) <= 1}
