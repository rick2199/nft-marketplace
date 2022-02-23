import NavLink from "./nav-link";

const Header: React.FC = () => (
  <header className="p-6 border-b ">
    <h1 className="text-3xl font-bold mb-3">Gambit Marketplace</h1>
    <nav className="text-blue-800 font-bold space-x-4">
      <NavLink href="/">Home</NavLink>
      <NavLink href="/">Sell Digital Asset</NavLink>
      <NavLink href="/">My Digital Assets</NavLink>
      <NavLink href="/">Creator Dashboard</NavLink>
    </nav>
  </header>
);

export default Header;
