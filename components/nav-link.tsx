import Link from "next/link";

const NavLink: React.FC<{ href: string }> = ({ children, href }) => (
  <Link href={href}>
    <a className="hover:text-blue-500 hover:underline">{children}</a>
  </Link>
);

export default NavLink;
